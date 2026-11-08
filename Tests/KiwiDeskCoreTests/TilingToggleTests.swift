import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The tiling toggle (#3008): a Space with tiling off is placed as
/// Floating, keeps its stored layout and its array, appends what
/// opens meanwhile and lays the same array out again on resume.
/// Each case runs its control first, so a fixture that never tiled
/// cannot pass. The display is pinned (#531).
@Suite("Tiling toggle", .serialized)
@MainActor
struct TilingToggleTests {
    private let space = SpaceID("1")

    private func makeCore() -> KiwiCore {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: dir)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.animation.isEnabled = false
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        return core
    }

    private func open(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(raw), pid: 1, appName: "A")
            )
        )
    }

    private func members(_ core: KiwiCore) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    @Test("tiling off lays out nothing and keeps the stored layout")
    func offLaysOutNothing() throws {
        let core = makeCore()
        open(core, 1)
        open(core, 2)
        core.retile()
        let tiled = core.tiler.placedFrames(state: core.state)
        #expect(tiled[WindowID(1)] != nil)
        #expect(tiled[WindowID(2)] != nil)

        #expect(core.execute("toggle_tiling").isSuccess)
        #expect(core.isTilingOff(space))
        #expect(core.tiler.placedFrames(state: core.state).isEmpty)
        #expect(core.state.workspaces[space]?.mode == .bsp)
        #expect(core.state.placementMode(of: space) == .floating)

        #expect(core.execute("toggle_tiling").isSuccess)
        #expect(!core.isTilingOff(space))
        #expect(core.tiler.placedFrames(state: core.state) == tiled)
    }

    @Test("a window opened while off joins the end; resume keeps order")
    func openedWhileOffJoinsTheEnd() throws {
        let core = makeCore()
        open(core, 1)
        open(core, 2)
        core.state.apply(.windowFocused(WindowID(1)))
        let before = members(core)
        // The control: with tiling on, a new window lands by the
        // spawn rule, not at the end.
        open(core, 3)
        #expect(members(core).last != WindowID(3))
        let order = members(core)

        core.execute("set_tiling", args: [.bool(false)])
        open(core, 4)
        #expect(members(core) == order + [WindowID(4)])
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        core.execute("set_tiling", args: [.bool(true)])
        #expect(
            members(core)
                == order.filter { $0 != WindowID(1) } + [WindowID(4)]
        )
        #expect(before.count == 2)
    }

    @Test("set_tiling forces a state without reading it")
    func setTilingForces() {
        let core = makeCore()
        core.execute("set_tiling", args: [.bool(false)])
        core.execute("set_tiling", args: [.bool(false)])
        #expect(core.isTilingOff(space))
        core.execute("set_tiling", args: [.bool(true), .string("1")])
        #expect(!core.isTilingOff(space))
        #expect(
            !core.execute("set_tiling", args: [.bool(true), .string("9")])
                .isSuccess
        )
    }

    @Test("start tiled: Space over profile over app-wide; a toggle over all")
    func startHierarchy() {
        #expect(TilingStart().startsTiled(space))
        #expect(!TilingStart(global: false).startsTiled(space))
        #expect(TilingStart(global: false, profile: true).startsTiled(space))
        #expect(
            !TilingStart(global: true, profile: true, spaces: [space: false])
                .startsTiled(space)
        )
        let core = makeCore()
        core.execute("set_tiling_start_global", args: [.bool(false)])
        #expect(core.isTilingOff(space))
        core.execute("tiling.set_start", args: [.bool(true)])
        #expect(!core.isTilingOff(space))
        core.execute("tiling.set_start", args: [.bool(false), .string("1")])
        #expect(core.isTilingOff(space))
        core.execute("tiling.set_start", args: [.null, .string("1")])
        #expect(!core.isTilingOff(space))
        core.execute("set_tiling", args: [.bool(false)])
        #expect(core.isTilingOff(space))
    }

    @Test("the toggle rekeys with a renumber and drops with its Space")
    func toggleFollowsItsSpace() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace(SpaceID("1"))
        state.workspaces.ensureSpace(SpaceID("2"))
        state.setTiling(false, for: SpaceID("1"))
        state.rekeyTilingToggle(SpaceID("1"), to: SpaceID("5"))
        #expect(state.tilingToggles[SpaceID("5")] == false)
        #expect(state.tilingToggles[SpaceID("1")] == nil)
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.execute("set_tiling", args: [.bool(false), .string("2")])
        core.forwardWindows(of: SpaceID("2"), to: space)
        #expect(core.state.tilingToggles[SpaceID("2")] == nil)
    }

    @Test("the ticks stand the rings and the shelf down, only when on")
    func ticksStandDown() {
        let core = makeCore()
        core.execute("set_tiling", args: [.bool(false)])
        #expect(!core.tilingOffHidesRings(on: space))
        core.execute("tiling.set_off_hides_borders", args: [.bool(true)])
        #expect(core.tilingOffHidesRings(on: space))
        core.execute("set_tiling", args: [.bool(true)])
        #expect(!core.tilingOffHidesRings(on: space))
    }

    @Test("tiling off wins the marker slot and keeps what it covers")
    func markerWinsTheSlot() {
        typealias Marker = SpaceBarItemView.Marker
        let covered = Marker.tilingOff(beside: .temporary)
        #expect(covered.symbol == "pause")
        #expect(covered.spaceState == .temporary)
        #expect(Marker.temporary.spaceState == .temporary)
        #expect(Marker.tilingOff(beside: nil).spaceState == nil)
    }

    @Test("Tiling Off for This Space is generation 12, on ⌃⌥T")
    func toggleTilingGeneration() {
        let rows = DefaultKeybindings.rows(ofGeneration: 12)
        #expect(rows == [DefaultKeybindings.toggleTilingRow()])
        #expect(
            rows.compactMap { KeyCombo.parse($0.combo) }
                == [KeyCombo.parse("control+option+t")]
        )
        #expect(rows.first?.lua == "KiwiDesk.toggle_tiling()")
        #expect(DefaultKeybindings.newestGeneration >= 12)
    }

    @Test("the settings round-trip their stored keys")
    func settingsRoundTrip() throws {
        var settings = TilingToggleSettings()
        settings.start = false
        settings.startOverride = [SpaceID("3"): true]
        settings.offHidesBars = true
        let data = try JSONEncoder().encode(settings)
        let json = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(
            Set(json.keys)
                == [
                    "start", "start_override", "off_hides_borders",
                    "off_hides_bars",
                ]
        )
        #expect(
            try JSONDecoder().decode(TilingToggleSettings.self, from: data)
                == settings
        )
        let empty = try JSONDecoder().decode(
            TilingToggleSettings.self,
            from: Data("{}".utf8)
        )
        #expect(empty == TilingToggleSettings())
    }
}
