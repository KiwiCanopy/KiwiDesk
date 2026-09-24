import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class DeleteRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// A profile delete asks every time, clean or dirty, in ONE
/// dialog whose Return picks Cancel (#1619). Which call sites
/// take this gate is `DiscardGateParityTests`' half. Locale
/// pinned per body (#740).
@Suite("Profile delete confirm (#1619)")
@MainActor
struct ProfileDeleteConfirmTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(hotkeyRegistrar: DeleteRegistrar())
        try core.saveGuiConfig(GuiConfig())
        return makeTestModel(core: core)
    }

    @Test("parks even with nothing staged")
    func parksWhenClean() throws {
        pinEnglish()
        let model = try makeModel()
        #expect(!model.isDirty)
        var ran = false
        model.confirmingProfileDelete("Work") { ran = true }
        #expect(!ran)
        let pending = try #require(model.pendingDiscard)
        #expect(pending.title == "Delete \u{201C}Work\u{201D}?")
        #expect(
            pending.message
                == "Its Spaces, layouts, rules and shortcuts will be "
                + "deleted. You can't undo this."
        )
        #expect(pending.confirmLabel == "Delete")
        #expect(pending.cancelIsDefault)
    }

    /// Staged edits fold into the delete's own message rather
    /// than a discard dialog ahead of it.
    @Test("staged edits fold into the one dialog")
    func dirtyFoldsIntoOneDialog() throws {
        pinEnglish()
        let model = try makeModel()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
        var ran = 0
        model.confirmingProfileDelete("Work") { ran += 1 }
        let pending = try #require(model.pendingDiscard)
        #expect(pending.title == "Delete \u{201C}Work\u{201D}?")
        #expect(pending.message.contains("haven't saved"))
        #expect(pending.cancelIsDefault)
        model.confirmPendingDiscard(pending)
        #expect(ran == 1)
        #expect(model.pendingDiscard == nil)
    }

    @Test("cancelling never deletes")
    func cancelKeepsTheProfile() throws {
        pinEnglish()
        let model = try makeModel()
        var ran = false
        model.confirmingProfileDelete("Work") { ran = true }
        model.cancelPendingDiscard()
        #expect(!ran)
    }

    /// The plain discard gate keeps its shared title and its
    /// verb-as-default behaviour.
    @Test("the discard gate keeps the shared dialog")
    func discardGateUnchanged() throws {
        pinEnglish()
        let model = try makeModel()
        model.config.settings.gapsGlobal.inner.horizontal += 7
        model.discardingEdits(message: "m", confirmLabel: "c") {}
        let pending = try #require(model.pendingDiscard)
        #expect(pending.title == nil)
        #expect(!pending.cancelIsDefault)
    }

    /// The host reads the flag; a field nothing renders is inert.
    @Test("the dialog host wires the default to Cancel")
    func hostWiresCancelDefault() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/DiscardConfirm.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.contains("pending.cancelIsDefault"))
        #expect(
            source.contains(
                "pending.cancelIsDefault ? .defaultAction : nil"
            )
        )
        #expect(source.contains("model.pendingDiscard?.title"))
    }
}
