import Foundation
import Testing

@testable import KiwiDeskCore

/// Integration tests for editing a stored profile's app-rule
/// override through the GUI path (#109):
/// `loadGuiConfig(editing:)` seeds the RESOLVED rules,
/// `overwriteProfile` stores only the sparse diff against the
/// base gui.json rules — deletions included (tombstone), and
/// never writes gui.json itself (`ProfileModesEditTests`' twin).
@Suite("Profile app-rules edit round-trip (#109)", .serialized)
@MainActor
struct ProfileAppRulesEditTests {

    // MARK: - Helpers

    private func makeGuiCore() -> KiwiCore {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-rulesedit-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.appRules = [
            "mail": SpaceID(1),
            "music": SpaceID(2),
        ]
        try? core.guiConfigStore.save(config)
        return core
    }

    private func saveWorkProfile(
        _ core: KiwiCore,
        appRules: AppRuleOverride? = nil
    ) throws {
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings(),
                appRules: appRules
            )
        )
    }

    /// Re-pins Mail, adds Safari, un-pins Music.
    private var override: AppRuleOverride {
        AppRuleOverride(rules: [
            "mail": SpaceID(3),
            "safari": SpaceID(4),
            "music": nil,
        ])
    }

    // MARK: - Seeding

    @Test("loadGuiConfig(editing:) seeds the RESOLVED rules")
    func editingSeedsResolvedRules() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, appRules: override)

        let config = try core.loadGuiConfig(editing: "Work")

        #expect(config.appRules["mail"] == SpaceID(3))
        #expect(config.appRules["safari"] == SpaceID(4))
        // The tombstoned base pin is absent from the resolved
        // map the tabs edit.
        #expect(config.appRules["music"] == nil)
    }

    // MARK: - Saving

    @Test("overwriteProfile stores the sparse diff only")
    func overwriteStoresSparseDiff() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core)

        var config = try core.loadGuiConfig(editing: "Work")
        config.appRules["mail"] = SpaceID(3)
        config.appRules["safari"] = SpaceID(4)
        config.appRules["music"] = nil
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        let stored = try #require(saved.appRules)
        #expect(stored == override)
    }

    @Test("Unchanged edit session preserves the override")
    func unchangedSavePreservesOverride() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, appRules: override)

        // Load for edit and save straight back.
        let config = try core.loadGuiConfig(editing: "Work")
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.appRules == override)
    }

    @Test("Reverting to base clears the override (nil, sparse)")
    func revertingClearsOverride() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, appRules: override)

        var config = try core.loadGuiConfig(editing: "Work")
        // Put every rule back to its base state.
        config.appRules = [
            "mail": SpaceID(1),
            "music": SpaceID(2),
        ]
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.appRules == nil)
        // The cleared override encodes as key ABSENT.
        let data = try JSONEncoder().encode(saved)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        #expect(!json.contains("\"app_rules\""))
    }

    @Test("overwriteProfile never writes gui.json")
    func overwriteLeavesSidecarAlone() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core)
        let sidecarURL = core.configDirectory
            .appendingPathComponent("gui.json")
        let before = try Data(contentsOf: sidecarURL)

        var config = try core.loadGuiConfig(editing: "Work")
        config.appRules["mail"] = SpaceID(9)
        try core.overwriteProfile(named: "Work", with: config)

        let after = try Data(contentsOf: sidecarURL)
        #expect(after == before)
    }
}
