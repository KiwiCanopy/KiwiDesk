import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The review's cases for the draft (#1393): a page pinned to its
/// profile, a left-out profile that stays tickable, and a pill
/// that counts what it lists.
@Suite("Rule reach, draft edge cases (#1393)", .serialized)
@MainActor
struct RuleReachModelEdgeTests {
    /// gui.json opens Mail in Space 1; Work (loaded) opens Spotify
    /// in Space 2 on its own; Home is stored and leaves Mail out.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(
            profile("Work", AppRuleOverride(rules: ["spotify": "2"]))
        )
        try core.profiles.write(
            profile("Home", AppRuleOverride(rules: ["mail": nil]))
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String, _ rules: AppRuleOverride?)
        -> Profile
    {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [:],
            settings: TilingSettings(),
            appRules: rules
        )
    }

    @Test("Save as New from the loaded page keeps its rules its own")
    func saveAsNewKeepsPageRules() throws {
        let model = try makeModel()
        #expect(model.config.appRules["spotify"] == SpaceID("2"))

        // Makes "Copy" current mid-save; the page stays Work's.
        model.saveAsNewProfile(named: "Copy")

        let base = model.core.guiConfigStore.load()?.appRules ?? [:]
        #expect(base["spotify"] == nil)
        #expect(base["mail"] == SpaceID("1"))
        let work = try model.core.profiles.read(name: "Work")
        #expect(work.appRules == AppRuleOverride(rules: ["spotify": "2"]))
    }

    @Test("A profile that left the shared rule out stays tickable")
    func leftOutIsTickable() throws {
        let model = try makeModel()
        let row = try #require(model.spaceReach("mail"))
        #expect(row.shared)
        #expect(row.leftOut == ["Home"])
        #expect(row.differing == ["Home"])

        model.setProfile(.space, "mail", "Home", true)
        model.updateActiveProfile()

        #expect(try model.core.profiles.read(name: "Home").appRules == nil)
    }

    @Test("A shared value edit counts the other profiles it moves")
    func countIncludesOtherProfiles() throws {
        let model = try makeModel()
        model.config.appRules["mail"] = SpaceID("2")
        // Work's own row plus nothing else follows the base here —
        // Home leaves Mail out — so add a follower.
        try model.core.profiles.write(profile("Travel", nil))
        model.reload()
        model.config.appRules["mail"] = SpaceID("2")

        let rows = model.reachDiffRows()
        #expect(rows.contains { $0.label.contains("Travel") })
        #expect(model.draftChangeCount >= 1 + rows.count)
    }

    @Test("A copy waits while the draft reaches other profiles")
    func copyWaitsOnReach() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        #expect(model.reachDiffRows().isEmpty)
        model.config.appRules["notes"] = SpaceID("2")
        #expect(model.reachDiffRows().isEmpty)

        model.config.appRules["spotify"] = SpaceID("2")
        model.setAllProfiles(.space, "spotify", true)

        #expect(!model.reachDiffRows().isEmpty)
    }

    /// The predicate above greys the copy button — the wiring,
    /// since a reason nothing reads greys nothing.
    @Test("the copy button reads the reach predicate")
    func copyButtonIsWired() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsFooter+Slots.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(source.contains(".disabled(copyBlockedReason != nil)"))
        #expect(source.contains("model.reachDiffRows().isEmpty"))
    }
}
