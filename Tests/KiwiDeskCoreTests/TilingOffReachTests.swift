import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Tiling off rows' storage (#3089): each value a profile's own
/// sparse leaf over an app-wide base in `gui.json`'s `tiling` group,
/// written through the "Applies to" tables, and a Save of a base
/// lays the Spaces out under it as the verbs do.
@Suite("Tiling off reach (#3089)", .serialized)
@MainActor
struct TilingOffReachTests {
    private typealias Table = RuleReachTable<Bool>
    private let space = SpaceID("1")

    /// A GUI-managed core with two profiles, `Work` the live one.
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-tiling-off-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.animation.isEnabled = false
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
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        return core
    }

    @Test("a profile writes a tick only where it holds one")
    func ticksAreSparse() throws {
        var toggle = TilingToggleSettings()
        let bare = try JSONEncoder().encode(toggle)
        let text = String(decoding: bare, as: UTF8.self)
        #expect(!text.contains("off_hides_borders"))
        #expect(!text.contains("off_hides_bars"))
        toggle.offHidesBorders = false
        toggle.offHidesBars = true
        let data = try JSONEncoder().encode(toggle)
        let back = try JSONDecoder().decode(
            TilingToggleSettings.self,
            from: data
        )
        #expect(back.offHidesBorders == false)
        #expect(back.offHidesBars == true)
        let absent = try JSONDecoder().decode(
            TilingToggleSettings.self,
            from: Data(#"{"start_override": {}}"#.utf8)
        )
        #expect(absent.offHidesBorders == nil)
        #expect(absent.offHidesBars == nil)
    }

    @Test("each tick resolves its own value over the base")
    func ticksResolve() {
        var toggle = TilingToggleSettings()
        for base in [false, true] {
            #expect(toggle.offHidesBorders(base: base) == base)
            #expect(toggle.offHidesBars(base: base) == base)
        }
        toggle.offHidesBorders = true
        toggle.offHidesBars = false
        #expect(toggle.offHidesBorders(base: false))
        #expect(!toggle.offHidesBars(base: true))
    }

    @Test("gui.json's tiling group round-trips both new leaves")
    func baseRoundTrips() throws {
        var config = GuiConfig()
        var wide = AppWideSettings()
        wide.tilingStartGlobal = false
        wide.tilingOffHidesBorders = true
        wide.tilingOffHidesBars = true
        config.appWide = wide
        let data = try JSONEncoder().encode(config)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let group = try #require(json["tiling"] as? [String: Bool])
        #expect(
            group == [
                "start_global": false, "off_hides_borders": true,
                "off_hides_bars": true,
            ]
        )
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide == wide)
    }

    @Test("a profile with no tick follows the base the verb writes")
    func verbWritesTheBase() throws {
        let core = try makeCore()
        let display = DisplayID(7)
        core.state.workspaces.assign(space, to: display)
        core.state.workspaces.activate(space)
        core.execute("set_tiling", args: [.bool(false)])
        #expect(!core.tilingOffHidesRings(on: space))
        core.execute("tiling.set_off_hides_borders", args: [.bool(true)])
        core.execute("tiling.set_off_hides_bars", args: [.bool(true)])
        #expect(core.appWide.tilingOffHidesBorders)
        #expect(core.appWide.tilingOffHidesBars)
        #expect(core.tiler.settings.tiling.offHidesBorders == nil)
        #expect(core.tilingOffHidesRings(on: space))
        #expect(core.tilingOffHidesShelf(on: display))
        // A profile's own value still wins over the base.
        core.tiler.settings.tiling.offHidesBorders = false
        core.tiler.settings.tiling.offHidesBars = false
        #expect(!core.tilingOffHidesRings(on: space))
        #expect(!core.tilingOffHidesShelf(on: display))
    }

    @Test("a Settings write of the start base retiles an untoggled Space")
    func baseSaveRetiles() throws {
        let core = try makeCore()
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(raw), pid: 1, appName: "A")
                )
            )
        }
        core.setAppWide(persisting: true) { $0.tilingStartGlobal = false }
        #expect(core.isTilingOff(space))
        var issued: [WindowID: CGRect] = [:]
        core.tiler.animation.apply = { id, frame, _ in issued[id] = frame }
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.tilingStart.apply(
            Table.tilingStartKey,
            value: true,
            reach: .shared(joining: []),
            editing: "Work"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.appWide.tilingStartGlobal)
        #expect(!core.isTilingOff(space))
        // The resume lays the row out: both windows were sent the
        // frames their layout draws.
        let slots = core.tiler.placedFrames(state: core.state)
        #expect(issued[WindowID(1)] == slots[WindowID(1)])
        #expect(issued[WindowID(2)] == slots[WindowID(2)])
        #expect(issued[WindowID(1)] != nil)
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.tilingStartGlobal)
        let work = try core.profiles.read(name: "Work")
        #expect(work.settings.tiling.start == nil)
    }

    @Test("a listed tick lands in that profile alone, the base kept")
    func listedTickIsTheProfiles() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.tilingOffHides.apply(
            Table.offHidesBarsKey,
            value: true,
            reach: .listed(["Work"]),
            editing: "Work"
        )
        try core.saveRuleReach(snapshot)
        #expect(!core.appWide.tilingOffHidesBars)
        let work = try core.profiles.read(name: "Work")
        #expect(work.settings.tiling.offHidesBars == true)
        #expect(work.settings.tiling.offHidesBorders == nil)
        let home = try core.profiles.read(name: "Home")
        #expect(home.settings.tiling.offHidesBars == nil)
        // The live profile's own value follows its file.
        #expect(core.tiler.settings.tiling.offHidesBars == true)
    }

    @Test("a shared write collapses a profile's equal tick")
    func sharedWriteCollapses() throws {
        let core = try makeCore()
        var home = try core.profiles.read(name: "Home")
        home.settings.tiling.offHidesBorders = false
        try core.profiles.write(home)
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.tilingOffHides.apply(
            Table.offHidesBordersKey,
            value: true,
            reach: .shared(joining: []),
            editing: "Work"
        )
        try core.saveRuleReach(snapshot)
        #expect(core.appWide.tilingOffHidesBorders)
        let reread = try core.profiles.read(name: "Home")
        #expect(reread.settings.tiling.offHidesBorders == nil)
    }
}
