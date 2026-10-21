import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `swap` names windows as well as directions (#2509): one id
/// swaps the focused window with it, two swap those two, and the
/// direction form is unchanged. The cross-Space trade is
/// `SwapWindowTradeTests`'.
@Suite("swap by window id (#2509)", .serialized)
@MainActor
struct SwapWindowIDTests {
    private static let one = SpaceID("1")
    private static let two = SpaceID("2")

    /// Space 1 holds 900001 and 900002 side by side, the later
    /// focused; Space 2, unshown, holds 900003 and 900004.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-swap-\(UUID().uuidString)")
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
        #expect(core.state.workspaces.activeSpace == Self.one)
        #expect(core.focusedWindowID == WindowID(900_002))
        return core
    }

    private func file(
        _ core: KiwiCore,
        _ raw: UInt32,
        in space: SpaceID,
        floating: Bool = false,
        fullscreen: Bool = false
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(raw),
                pid: 900_002,
                appName: "B",
                isFloating: floating,
                isFullscreen: fullscreen
            )
        )
        core.state.workspaces.add(WindowID(raw), to: space)
    }

    private func row(_ core: KiwiCore, _ space: SpaceID) -> [UInt32] {
        core.state.workspaces[space]?.windows.map(\.raw) ?? []
    }

    @Test("the record takes an optional window after the direction")
    func recordTakesAWindow() {
        let arguments =
            APIReference.entry(named: "swap")?.record.arguments ?? []
        #expect(APIReference.windowArgumentIndex("swap") == 1)
        #expect(arguments.last?.isOptional == true)
        let core = makeCore()
        // One id acts on the focus and keeps the #292 preflight;
        // a second names both windows and skips it.
        #expect(core.impliesFocus("swap", [.number(900_003)]))
        #expect(
            !core.impliesFocus(
                "swap",
                [.number(900_003), .number(900_001)]
            )
        )
    }

    /// `swap_here` acts on the focused slot, so its id must not
    /// read as naming its window and skip the #292 preflight.
    @Test("swap_here keeps the #292 preflight")
    func swapHereKeepsThePreflight() {
        #expect(APIReference.windowArgumentIndex("swap_here") == nil)
        let core = makeCore()
        #expect(core.impliesFocus("swap_here", [.number(900_003)]))
    }

    @Test("one id swaps the focused window with it in its Space")
    func oneIDSwapsWithTheFocus() {
        let core = makeCore()
        let response = core.execute("swap", args: [.number(900_001)])
        #expect(response.isSuccess)
        #expect(row(core, Self.one) == [900_002, 900_001])
        #expect(core.focusedWindowID == WindowID(900_002))
    }

    @Test("two ids swap two windows neither of which is focused")
    func twoIDsSwapAnyPair() {
        let core = makeCore()
        let response = core.execute(
            "swap",
            args: [.string("900003"), .string("900004")]
        )
        #expect(response.isSuccess)
        #expect(row(core, Self.two) == [900_004, 900_003])
        #expect(row(core, Self.one) == [900_001, 900_002])
        #expect(core.focusedWindowID == WindowID(900_002))
    }

    @Test("a direction still swaps the focused window's neighbour")
    func directionIsUnchanged() {
        let core = makeCore()
        #expect(core.execute("swap", args: [.string("left")]).isSuccess)
        #expect(row(core, Self.one) == [900_002, 900_001])
        let bad = core.execute("swap", args: [.string("sideways")])
        #expect(bad.error == "expected left|right|up|down or a window id")
    }

    @Test("an id no tracked window carries is refused, either place")
    func unknownRefused() {
        let core = makeCore()
        let first = core.execute("swap", args: [.number(99)])
        #expect(first.error == "unknown window: 99")
        let second = core.execute(
            "swap",
            args: [.number(900_001), .number(98)]
        )
        #expect(second.error == "unknown window: 98")
        let direction = core.execute(
            "swap",
            args: [.string("left"), .number(97)]
        )
        #expect(direction.error == "unknown window: 97")
        #expect(row(core, Self.one) == [900_001, 900_002])
        #expect(row(core, Self.two) == [900_003, 900_004])
    }

    @Test("a direction and an id swap that window with its neighbour")
    func directionMovesTheNamedWindow() {
        let core = makeCore()
        let response = core.execute(
            "swap",
            args: [.string("right"), .number(900_001)]
        )
        #expect(response.isSuccess)
        #expect(row(core, Self.one) == [900_002, 900_001])
        // The named window moved; the focus did not.
        #expect(core.focusedWindowID == WindowID(900_002))
        let away = core.execute(
            "swap",
            args: [.string("left"), .number(900_003)]
        )
        #expect(
            away.error == "window 900003 is not in the Space you are on"
        )
        #expect(row(core, Self.two) == [900_003, 900_004])
    }

    @Test("a window is never swapped with itself")
    func selfRefused() {
        let core = makeCore()
        let response = core.execute("swap", args: [.number(900_002)])
        #expect(response.error == "cannot swap a window with itself")
    }

    /// A float has no slot to trade: refused on either side, the
    /// flag or a floating-mode Space alike (`EffectiveFloat`).
    @Test("an effective float is refused on either side")
    func floatRefused() {
        let core = makeCore()
        file(core, 900_005, in: Self.two, floating: true)
        let flagged = core.execute("swap", args: [.number(900_005)])
        #expect(flagged.error == "window 900005 is floating")
        core.state.workspaces.setMode(Self.two, .floating)
        let member = core.execute(
            "swap",
            args: [.number(900_001), .number(900_003)]
        )
        #expect(member.error == "window 900003 is floating")
        #expect(row(core, Self.one) == [900_001, 900_002])
        #expect(row(core, Self.two) == [900_003, 900_004, 900_005])
    }

    @Test("a native full-screen window is refused")
    func fullscreenRefused() {
        let core = makeCore()
        file(core, 900_006, in: Self.two, fullscreen: true)
        let response = core.execute("swap", args: [.number(900_006)])
        #expect(response.error == "window 900006 is full screen")
        #expect(row(core, Self.one) == [900_001, 900_002])
    }
}
