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

    /// Both live Save paths reach the per-entry write after their
    /// `gui.json` write, which may have minted the config.
    @Test("both Save paths call the per-entry write")
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
            let call = try #require(
                text.range(of: "try persistBindingEdits()"),
                "\(file) never writes the binding edits"
            )
            let save = try #require(text.range(of: "saveGuiConfig("))
            #expect(save.lowerBound < call.lowerBound, "\(file)")
        }
    }
}
