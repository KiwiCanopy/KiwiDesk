import Foundation
import Testing

@testable import KiwiDeskCore

/// `mode_cycle` is stored as `space_history` is (#453, #1655): a
/// global base in `gui.json` and a sparse per-profile override,
/// resolved live and written through the "Applies to" table, a
/// stored page's diff and the Lua verb.
@Suite("Layout cycle setting storage (#453)", .serialized)
@MainActor
struct ModeCycleSettingTests {
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-cycle-\(UUID().uuidString)")
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

    private func reapply(_ core: KiwiCore, cycle: [LayoutMode]?) {
        core.reapplyStructuredOverrides(
            Profile(
                name: "P",
                monitorSets: [MonitorSet(monitors: ["P:1x1"])],
                spaceModes: [:],
                settings: TilingSettings(),
                modeCycle: cycle
            )
        )
    }

    @Test("a profile writes the key only where it diverges")
    func profileIsSparse() throws {
        let core = try makeCore()
        let plain = try String(
            contentsOf: core.profiles.fileURL(name: "Home"),
            encoding: .utf8
        )
        #expect(!plain.contains("mode_cycle"))
        var work = try core.profiles.read(name: "Work")
        work.modeCycle = [.stack, .monocle]
        try core.profiles.write(work)
        let written = try String(
            contentsOf: core.profiles.fileURL(name: "Work"),
            encoding: .utf8
        )
        #expect(written.contains(#""mode_cycle""#))
        let reread = try core.profiles.read(name: "Work")
        #expect(reread.modeCycle == [.stack, .monocle])
    }

    @Test("a profile's list the cycle cannot walk fails the file")
    func profileDecodeIsStrict() throws {
        let profile = Profile(
            name: "P",
            monitorSets: [MonitorSet(monitors: ["P:1x1"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        let data = try JSONEncoder().encode(profile)
        var root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        root["mode_cycle"] = ["bsp"]
        let short = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Profile.self, from: short)
        }
        root["mode_cycle"] = ["grid", "bsp"]
        let good = try JSONSerialization.data(withJSONObject: root)
        let decoded = try JSONDecoder().decode(Profile.self, from: good)
        #expect(decoded.modeCycle == [.grid, .bsp])
    }

    @Test("the table writes a listed value to the profile alone")
    func reachWritesTheOverride() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.modeCycle.apply(
            RuleReachTable<[LayoutMode]>.modeCycleKey,
            value: [.stack, .monocle],
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(snapshot.isEdited)
        try core.saveRuleReach(snapshot)
        let work = try core.profiles.read(name: "Work")
        #expect(work.modeCycle == [.stack, .monocle])
        #expect(try core.profiles.read(name: "Home").modeCycle == nil)
        #expect(
            core.guiConfigStore.load()?.modeCycle == ModeCycle.defaultList
        )
    }

    @Test("a shared value moves the base, and the live resolve")
    func reachMovesTheBase() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.modeCycle.apply(
            RuleReachTable<[LayoutMode]>.modeCycleKey,
            value: [.grid, .track],
            reach: .shared(joining: []),
            editing: "Home"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.guiConfigStore.load()?.modeCycle == [.grid, .track])
        #expect(core.modeCycle.list == [.grid, .track])
    }

    @Test("a stored page resolves the override and diffs it back")
    func storedPageRoundTrips() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.modeCycle = [.stack, .monocle]
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        #expect(page.modeCycle == [.stack, .monocle])
        page.modeCycle = ModeCycle.defaultList
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: true
        )
        // Back on the base: the key leaves the file.
        #expect(try core.profiles.read(name: "Work").modeCycle == nil)
    }

    @Test("a checklist Save leaves the stored override to the table")
    func storedPageKeepsWithoutRules() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.modeCycle = [.stack, .monocle]
        try core.profiles.write(work)
        var page = try core.loadGuiConfig(editing: "Work")
        page.modeCycle = [.grid, .bsp]
        try core.overwriteProfile(
            named: "Work",
            with: page,
            writingRules: false
        )
        #expect(
            try core.profiles.read(name: "Work").modeCycle
                == [.stack, .monocle]
        )
    }

    @Test("a profile apply resolves its override over the base")
    func profileApplyResolves() throws {
        let core = try makeCore()
        reapply(core, cycle: [.stack, .monocle])
        #expect(core.modeCycle.list == [.stack, .monocle])
        reapply(core, cycle: nil)
        #expect(core.modeCycle.list == ModeCycle.defaultList)
    }

    @Test("the verb writes the base, so an override still wins")
    func verbWritesTheBase() throws {
        let core = try makeCore()
        reapply(core, cycle: [.stack, .monocle])
        core.execute(
            "set_mode_cycle",
            args: [.array([.string("grid"), .string("track")])]
        )
        #expect(core.modeCycle.base == [.grid, .track])
        #expect(core.modeCycle.list == [.stack, .monocle])
    }

    @Test("Lua-owned: a profile apply keeps init.lua's base")
    func luaOwnedKeepsTheBase() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-cycle-\(UUID().uuidString)")
        )
        #expect(!core.isGuiManaged)
        core.execute(
            "set_mode_cycle",
            args: [.array([.string("grid"), .string("track")])]
        )
        reapply(core, cycle: [.stack, .monocle])
        #expect(core.modeCycle.list == [.stack, .monocle])
        reapply(core, cycle: nil)
        #expect(core.modeCycle.list == [.grid, .track])
    }

    @Test("a config load drops the profile override with the base")
    func loadResets() {
        // Lua-owned, so no gui.json pass re-seeds what the reset
        // cleared and the reset alone answers.
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-cycle-\(UUID().uuidString)")
        )
        reapply(core, cycle: [.stack, .monocle])
        core.modeCycle.base = [.grid, .track]
        core.loadConfig()
        #expect(core.modeCycle.profileOverride == nil)
        #expect(core.modeCycle.base == ModeCycle.defaultList)
    }

    @Test("loading a profile, then reloading, walks its own list")
    func profileLoadAndReloadResolve() throws {
        let core = try makeCore()
        var work = try core.profiles.read(name: "Work")
        work.modeCycle = [.stack, .monocle]
        try core.profiles.write(work)
        try core.loadProfile(named: "Work")
        #expect(core.modeCycle.list == [.stack, .monocle])
        core.loadConfig()
        #expect(core.modeCycle.list == [.stack, .monocle])
        try core.loadProfile(named: "Home")
        #expect(core.modeCycle.list == ModeCycle.defaultList)
    }
}
