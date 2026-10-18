import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class LatchRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// A file a newer KiwiDesk wrote latches Settings' Save up front
/// (#2324 ruling 2): greyed with the reason before any of its
/// writes, rather than a Save that writes other files and then
/// fails. Locale pinned per body (#740).
@Suite("A newer file greys Settings' Save (#2324)", .serialized)
@MainActor
struct NewerFormatSaveLatchTests {
    /// A dirty draft over a saved sidecar.
    private func makeDirtyModel() throws -> SettingsModel {
        let core = makeTestCore(hotkeyRegistrar: LatchRegistrar())
        try core.saveGuiConfig(GuiConfig())
        let model = makeTestModel(core: core)
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
        return model
    }

    /// Re-stamps `file`'s top-level `format`.
    private func restamp(_ file: URL, to format: Int) throws {
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: file)
            ) as? [String: Any]
        )
        root["format"] = format
        try JSONSerialization.data(withJSONObject: root)
            .write(to: file)
    }

    @Test("a newer gui.json greys Save and says why")
    func newerSidecarGreysSave() throws {
        LocalizationManager.shared.select("en")
        let model = try makeDirtyModel()
        model.refreshProfiles()
        #expect(model.writeLatch == nil)
        let enabled = model.primarySaveEnabled
        let file = model.core.guiConfigStore.url
        try restamp(file, to: GuiConfig.currentFormat + 1)
        model.refreshProfiles()
        #expect(model.writeLatch?.artifact == .guiConfig)
        #expect(enabled)
        #expect(!model.primarySaveEnabled)
        #expect(
            model.primarySaveBlockedReason
                == "A newer KiwiDesk saved gui.json, so this version "
                + "won't overwrite it. Update KiwiDesk to keep syncing."
        )
        let before = try Data(contentsOf: file)
        model.performPrimarySave()
        #expect(try Data(contentsOf: file) == before)
    }

    @Test("a thrown refusal reads as its sentence, else as the log")
    func detailNarratesTheRefusal() {
        LocalizationManager.shared.select("en")
        let refusal = NewerFormatOnDisk(
            artifact: .profiles,
            profile: "Desk",
            format: 99
        )
        #expect(
            NewerFormatText.detail(refusal)
                == "A newer KiwiDesk saved Desk.json, so this version "
                + "left it unchanged. Update KiwiDesk to keep syncing."
        )
        struct Other: Error {}
        #expect(NewerFormatText.detail(Other()) == "\(Other())")
    }
}
