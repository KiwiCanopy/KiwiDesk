import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Two windows in different Spaces trade places, each taking the
/// other's slot (#2509): the membership moves both ways at once,
/// `swap` keeps focus on your window wherever it lands,
/// `swap_here` keeps you in your slot, and a sticky window keeps
/// its #445 refusal.
@Suite("swap trades windows between Spaces (#2509)", .serialized)
@MainActor
struct SwapWindowTradeTests {
    private static let one = SpaceID("1")
    private static let two = SpaceID("2")
    private static let three = SpaceID("3")

    /// Space 1 (active): 900001, 900002 focused. Space 2:
    /// 900003, 900004. Space 3: 900005, 900006. Neither 2 nor 3
    /// is shown.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-trade-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for raw in [UInt32(900_001), 900_002] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_001,
                        appName: "A"
                    )
                )
            )
        }
        for raw in [UInt32(900_003), 900_004] {
            file(core, raw, in: Self.two)
        }
        for raw in [UInt32(900_005), 900_006] {
            file(core, raw, in: Self.three)
        }
        #expect(core.focusedWindowID == WindowID(900_002))
        return core
    }

    private func file(
        _ core: KiwiCore,
        _ raw: UInt32,
        in space: SpaceID,
        sticky: StickyScope = .none
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(raw),
                pid: 900_002,
                appName: "B",
                stickyScope: sticky
            )
        )
        core.state.workspaces.add(WindowID(raw), to: space)
    }

    private func row(_ core: KiwiCore, _ space: SpaceID) -> [UInt32] {
        core.state.workspaces[space]?.windows.map(\.raw) ?? []
    }

    @Test("the focused window trades slots with one in another Space")
    func focusedTradesAcross() {
        let core = makeCore()
        let response = core.execute("swap", args: [.number(900_003)])
        #expect(response.isSuccess)
        #expect(row(core, Self.one) == [900_001, 900_003])
        #expect(row(core, Self.two) == [900_002, 900_004])
        #expect(
            core.state.workspaces.space(of: WindowID(900_002))
                == Self.two
        )
        // Focus goes with your window, as a direction swap's does:
        // its Space becomes the one you are on.
        #expect(core.state.workspaces.activeSpace == Self.two)
        #expect(core.focusedWindowID == WindowID(900_002))
    }

    @Test("two ids trade between Spaces nobody shows, focus untouched")
    func unshownPairTrades() {
        let core = makeCore()
        let response = core.execute(
            "swap",
            args: [.number(900_004), .number(900_005)]
        )
        #expect(response.isSuccess)
        #expect(row(core, Self.two) == [900_003, 900_005])
        #expect(row(core, Self.three) == [900_004, 900_006])
        #expect(row(core, Self.one) == [900_001, 900_002])
        #expect(core.focusedWindowID == WindowID(900_002))
    }

    /// #1518's ruling for a named move: a window filed into the
    /// Space the user is on becomes that Space's focus.
    @Test("a window traded into the active Space takes its focus")
    func incomingTakesTheFocus() {
        let core = makeCore()
        core.execute(
            "swap",
            args: [.number(900_001), .number(900_006)]
        )
        #expect(row(core, Self.one) == [900_006, 900_002])
        #expect(row(core, Self.three) == [900_005, 900_001])
        #expect(core.focusedWindowID == WindowID(900_006))
    }

    @Test("swap_here brings the window into your slot and focus")
    func swapHereStays() {
        let core = makeCore()
        let response = core.execute(
            "swap_here",
            args: [.number(900_003)]
        )
        #expect(response.isSuccess)
        #expect(row(core, Self.one) == [900_001, 900_003])
        #expect(row(core, Self.two) == [900_002, 900_004])
        #expect(core.state.workspaces.activeSpace == Self.one)
        #expect(core.focusedWindowID == WindowID(900_003))
        #expect(
            core.state.workspaces[Self.two]?.focused
                == WindowID(900_002)
        )
    }

    @Test("swap_here in your own Space focuses the incoming window")
    func swapHereSameSpace() {
        let core = makeCore()
        core.execute("swap_here", args: [.number(900_001)])
        #expect(row(core, Self.one) == [900_002, 900_001])
        #expect(core.focusedWindowID == WindowID(900_001))
        let direction = core.execute("swap_here", args: [.string("left")])
        #expect(direction.error == "expected window id")
        let unknown = core.execute("swap_here", args: [.number(99)])
        #expect(unknown.error == "unknown window: 99")
    }

    @Test("each window takes the other's track break and weight")
    func slotCarriesItsBreak() {
        let core = makeCore()
        core.state.workspaces.withSpace(Self.two) {
            $0.trackBreaks = [WindowID(900_004)]
            $0.trackWeights = [WindowID(900_004): 2]
        }
        core.execute("swap", args: [.number(900_004)])
        let two = core.state.workspaces[Self.two]
        #expect(two?.windows.map(\.raw) == [900_003, 900_002])
        #expect(two?.trackBreaks == [WindowID(900_002)])
        #expect(two?.trackWeights == [WindowID(900_002): 2])
    }

    @Test("a sticky window keeps its move refusal")
    func stickyRefused() {
        let core = makeCore()
        file(core, 900_007, in: Self.two, sticky: .global)
        core.execute("swap", args: [.number(900_007)])
        #expect(row(core, Self.one) == [900_001, 900_002])
        #expect(row(core, Self.two) == [900_003, 900_004, 900_007])
        core.execute(
            "swap",
            args: [.number(900_007), .number(900_005)]
        )
        #expect(row(core, Self.three) == [900_005, 900_006])
    }

    /// Two screens, each showing its Space: the windows cross
    /// screens with their Spaces' slots, and both stay drawn.
    @Test("windows on two screens trade across them")
    func tradesAcrossScreens() throws {
        let core = makeCore()
        for display in [
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            Display(
                id: DisplayID(2),
                name: "B",
                frame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
            ),
        ] {
            core.state.workspaces.upsertDisplay(display)
        }
        core.state.workspaces.assign(Self.one, to: DisplayID(1))
        core.state.workspaces.assign(Self.two, to: DisplayID(2))
        core.state.workspaces.show(Self.two, on: DisplayID(2))
        try #require(core.state.workspaces.visibleSpaces.contains(Self.two))
        core.execute("swap", args: [.number(900_003)])
        #expect(row(core, Self.one) == [900_001, 900_003])
        #expect(row(core, Self.two) == [900_002, 900_004])
        let home = try #require(
            core.state.workspaces.space(of: WindowID(900_002))
        )
        #expect(core.state.workspaces.display(of: home) == DisplayID(2))
        #expect(core.state.workspaces.activeSpace == Self.two)
        #expect(core.focusedWindowID == WindowID(900_002))
        // Both screens still show a Space: the one you left stays
        // up on its screen. Frames are not compared — every fake
        // display resolves to the one host screen.
        #expect(core.state.workspaces.visibleSpaces.contains(Self.one))
        #expect(core.state.workspaces.visibleSpaces.contains(Self.two))
    }
}

/// The slot hand-over itself, on pure model state.
@Suite("Space.replace (#2509)")
struct SpaceReplaceTests {
    @Test("the newcomer takes the index, break, weights and focus")
    func replaceTakesTheSlot() {
        let a = WindowID(1)
        let b = WindowID(2)
        let c = WindowID(3)
        var space = Space(
            id: SpaceID("1"),
            mode: .track,
            windows: [a, b],
            focused: b,
            stackWeights: [b: 0.4],
            scrollRest: ScrollRest(
                offset: 10,
                slot: .init(window: b, position: 100, restingOn: nil)
            ),
            trackBreaks: [b],
            handedBreaks: [b],
            trackWeights: [b: 1.5]
        )
        space.replace(b, with: c)
        #expect(space.windows == [a, c])
        #expect(space.focused == c)
        #expect(space.trackBreaks == [c])
        #expect(space.handedBreaks.isEmpty)
        #expect(space.trackWeights == [c: 1.5])
        #expect(space.stackWeights == [c: 0.4])
        #expect(space.scrollRest?.slot == nil)
        // A member never takes a slot twice.
        space.replace(a, with: c)
        #expect(space.windows == [a, c])
    }
}
