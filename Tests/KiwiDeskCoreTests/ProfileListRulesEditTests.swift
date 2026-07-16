import Foundation
import Testing

@testable import KiwiDeskCore

/// Stored-profile edit coverage for float and hidden ignore
/// overrides (#287). Float uses the GUI's resolve/edit/diff cycle;
/// ignore has no editor and must survive every GUI write verbatim.
@Suite("Profile float/ignore edit round-trip (#287)", .serialized)
@MainActor
struct ProfileListRulesEditTests {
    private func makeCore() throws -> KiwiCore {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-list-edit-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.floatRules = ["base.float", "shared.float"]
        config.ignoreRules = ["base.ignore", "shared.ignore"]
        try core.guiConfigStore.save(config)
        return core
    }

    private var floatOverride: RuleListOverride {
        RuleListOverride(rules: [
            "base.float": nil,
            "profile.float": true,
        ])
    }

    private var ignoreOverride: RuleListOverride {
        RuleListOverride(rules: [
            "base.ignore": nil,
            "profile.ignore": true,
            "stale.ignore": nil,
        ])
    }

    private func saveWork(_ core: KiwiCore) throws {
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings(),
                floatRules: floatOverride,
                ignoreRules: ignoreOverride
            )
        )
    }

    @Test("Stored editor seeds resolved float and ignore rules")
    func editingSeedsResolvedLists() throws {
        let core = try makeCore()
        try saveWork(core)

        let config = try core.loadGuiConfig(editing: "Work")

        #expect(
            Set(config.floatRules) == [
                "shared.float", "profile.float",
            ]
        )
        #expect(
            Set(config.ignoreRules) == [
                "shared.ignore", "profile.ignore",
            ]
        )
    }

    @Test("Float edits store a sparse diff")
    func floatEditStoresSparseDiff() throws {
        let core = try makeCore()
        try saveWork(core)
        var config = try core.loadGuiConfig(editing: "Work")
        config.floatRules = ["shared.float", "other.float"]

        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(
            saved.floatRules
                == RuleListOverride(rules: [
                    "base.float": nil,
                    "other.float": true,
                ])
        )
    }

    @Test("Hidden ignore override survives profile overwrite")
    func overwritePreservesIgnore() throws {
        let core = try makeCore()
        try saveWork(core)
        let config = try core.loadGuiConfig(editing: "Work")

        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.ignoreRules == ignoreOverride)
    }

    @Test("Hidden ignore override survives profile copy")
    func copyPreservesIgnore() throws {
        let core = try makeCore()
        try saveWork(core)
        let config = try core.loadGuiConfig(editing: "Work")

        let name = try core.copyProfile(
            named: "Work",
            to: "Copy",
            with: config
        )

        let copy = try core.profiles.read(name: name)
        #expect(copy.ignoreRules == ignoreOverride)
    }

    @Test("Rename preserves both list-rule overrides")
    func renamePreservesRules() throws {
        let core = try makeCore()
        try saveWork(core)

        try core.renameProfile(from: "Work", to: "Studio")

        let renamed = try core.profiles.read(name: "Studio")
        #expect(renamed.floatRules == floatOverride)
        #expect(renamed.ignoreRules == ignoreOverride)
    }

    @Test("Global base save never rewrites profile overrides")
    func globalSaveLeavesProfileAlone() throws {
        let core = try makeCore()
        try saveWork(core)
        let profileURL = core.configDirectory
            .appendingPathComponent("profiles/Work.json")
        let before = try Data(contentsOf: profileURL)
        var global = try #require(core.guiConfigStore.load())
        global.floatRules = ["changed.float"]
        global.ignoreRules = ["changed.ignore"]

        try core.saveGuiConfig(global)

        let after = try Data(contentsOf: profileURL)
        #expect(after == before)
        let saved = try core.profiles.read(name: "Work")
        #expect(saved.floatRules == floatOverride)
        #expect(saved.ignoreRules == ignoreOverride)
    }

    @Test("Profile JSON uses bare sparse rule objects")
    func jsonShape() throws {
        let core = try makeCore()
        try saveWork(core)
        let saved = try core.profiles.read(name: "Work")
        let data = try JSONEncoder().encode(saved)
        let root = try #require(
            JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let floats = try #require(
            root["float_rules"] as? [String: Any]
        )
        let ignores = try #require(
            root["ignore_rules"] as? [String: Any]
        )
        #expect(floats["profile.float"] as? Bool == true)
        #expect(floats["base.float"] is NSNull)
        #expect(ignores["profile.ignore"] as? Bool == true)
        #expect(ignores["stale.ignore"] is NSNull)
    }
}
