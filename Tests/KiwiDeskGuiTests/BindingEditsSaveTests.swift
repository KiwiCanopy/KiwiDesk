import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Settings Save writes the draft's binding EDITS, per entry
/// (#2324): a row the user never touched keeps whatever Core wrote
/// since the draft was read — a re-key, a promotion — instead of
/// the draft's old copy of it.
@MainActor
@Suite("Settings Save writes binding edits per entry (#2324)")
struct BindingEditsSaveTests {
    @Test("an untouched row keeps Core's later write")
    func untouchedRowKeepsCore() throws {
        let (_, model) = DesktopBindingFixture.makeCard()
        try model.core.guiConfigStore.save(GuiConfig())
        let pending: [DesktopKey: DesktopBinding] = [
            .number(1): DesktopBinding(profile: "Laptop", desktop: 1)
        ]
        model.config.profileBindings = pending
        model.cleanConfig.profileBindings = pending
        // Core promotes the row underneath the open draft.
        let promoted = DesktopBinding(
            entries: [.init(id: .legacy(name: "Laptop"), name: "Laptop")],
            desktop: 1
        )
        try model.core.guiConfigStore.saveBindings([.number(1): promoted])
        // The user edits another Desktop only.
        model.config.profileBindings[.number(2)] =
            DesktopBinding(profile: "Dual", desktop: 2)
        try model.persistBindingEdits()
        let stored = model.core.guiConfigStore.bindingsFile.load()
            .profileBindings
        #expect(stored[.number(1)]?.entries.first?.id != nil)
        #expect(stored[.number(2)]?.names == ["Dual"])
    }

    /// The edits land BEFORE the `gui.json` save, whose reload then
    /// applies them — save where that save mints the config the
    /// binding door requires, where they land after it.
    @Test("the edits land around the save in the ruled order")
    func editsOrderAroundTheSave() throws {
        let (_, model) = DesktopBindingFixture.makeCard()
        let store = model.core.guiConfigStore
        func stored(_ number: Int) -> Bool {
            store.bindingsFile.load().profileBindings[.number(number)]
                != nil
        }
        model.config.profileBindings[.number(2)] =
            DesktopBinding(profile: "Dual", desktop: 2)
        var seenInSave: Bool?
        try model.savingBindingEdits {
            seenInSave = stored(2)
            try store.save(GuiConfig())
        }
        #expect(seenInSave == false)
        #expect(stored(2))
        model.config.profileBindings[.number(3)] =
            DesktopBinding(profile: "Dual", desktop: 3)
        try model.savingBindingEdits { seenInSave = stored(3) }
        #expect(seenInSave == true)
    }

    /// Both live Save paths run their `gui.json` write INSIDE the
    /// one ordering seam, so the reload applies the new bindings.
    @Test("both Save paths order the write through the seam")
    func savePathsAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        for file in [
            "SettingsModel+Globals.swift", "SettingsModel+Profiles.swift",
        ] {
            let text = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            let seam = try #require(
                text.range(of: "try savingBindingEdits {"),
                "\(file) saves outside the binding seam"
            )
            // The closure's own body: up to its first closing line
            // at the seam's indentation.
            let body = text[seam.upperBound...]
            let end =
                body.range(of: "\n            }\n")
                ?? body.range(of: "\n            }")
            let closure = end.map { body[..<$0.lowerBound] } ?? body
            #expect(
                closure.contains("saveGuiConfig(sidecarConfig)"),
                "\(file)'s gui.json save is outside the seam"
            )
        }
    }
}
