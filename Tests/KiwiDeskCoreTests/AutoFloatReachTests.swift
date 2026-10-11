import Foundation
import Testing

@testable import KiwiDeskCore

/// The Automatic floating card's two families reach profiles the
/// way App Rules' others do (#2173, #1393): the Tile list per app,
/// the switch as one key, a listed value written to the profile
/// alone and a shared one to `gui.json`.
@Suite("Automatic float reach (#2173)", .serialized)
@MainActor
struct AutoFloatReachTests {
    private static let steam = "com.valvesoftware.steam"

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-autoreach-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for name in ["Home", "Work"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        return core
    }

    @Test("a listed Tile rule lands in that profile alone")
    func listedTileRule() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.tileRules.apply(
            Self.steam,
            value: [Self.steam],
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(snapshot.isEdited)
        try core.saveRuleReach(snapshot)
        let work = try core.profiles.read(name: "Work")
        #expect(
            work.tileRules?.resolved(onto: [], normalizing: { $0 })
                == [Self.steam]
        )
        #expect(try core.profiles.read(name: "Home").tileRules == nil)
        #expect(core.guiConfigStore.load()?.tileRules.isEmpty == true)
    }

    @Test("a shared Tile rule and switch move the base")
    func sharedValuesMoveTheBase() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.tileRules.apply(
            Self.steam,
            value: [Self.steam],
            reach: .shared(joining: []),
            editing: "Home"
        )
        snapshot.floatAutomatically.apply(
            RuleReachTable<Bool>.floatAutomaticallyKey,
            value: false,
            reach: .shared(joining: []),
            editing: "Home"
        )
        try core.saveRuleReach(snapshot)
        let sidecar = try #require(core.guiConfigStore.load())
        #expect(sidecar.tileRules == [Self.steam])
        #expect(!sidecar.floatAutomatically)
        #expect(!core.eventLoop.floatRules.guess.enabled)
    }

    @Test("a listed switch is a sparse profile override")
    func listedSwitch() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.floatAutomatically.apply(
            RuleReachTable<Bool>.floatAutomaticallyKey,
            value: false,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        try core.saveRuleReach(snapshot)
        #expect(
            try core.profiles.read(name: "Work").floatAutomatically == false
        )
        #expect(try core.profiles.read(name: "Home").floatAutomatically == nil)
        #expect(core.guiConfigStore.load()?.floatAutomatically == true)
    }

    @Test("a stored page resolves both and diffs them back")
    func storedPageRoundTrips() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.tileRules = RuleListOverride(rules: [Self.steam: true])
        work.floatAutomatically = false
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        #expect(page.tileRules == [Self.steam])
        #expect(!page.floatAutomatically)
        page.tileRules = []
        page.floatAutomatically = true
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        let back = try core.profiles.read(name: "Work")
        #expect(back.floatAutomatically == nil)
        #expect(back.tileRules == nil)
    }

    @Test("a Save leaving the rules to the checklist keeps them")
    func overwriteKeepsStoredRules() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.tileRules = RuleListOverride(rules: [Self.steam: true])
        work.floatAutomatically = false
        try core.profiles.write(work)
        try core.overwriteProfile(
            named: "Work",
            with: GuiConfig(),
            writingRules: false
        )
        let back = try core.profiles.read(name: "Work")
        #expect(back.tileRules == RuleListOverride(rules: [Self.steam: true]))
        #expect(back.floatAutomatically == false)
    }
}
