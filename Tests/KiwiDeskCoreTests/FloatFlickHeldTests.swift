import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float flicked again inside the echo grace of its last clamp
/// opens a gesture (#2087): a move while the button is still held,
/// and a move whose release is in flight (the button reads up, no
/// release recorded yet), answer the hand when the press began
/// after our write. Floats only (#1798). Driven through the real
/// `.windowMoved` arm.
@Suite("Float flick held and in-flight release (#2087)", .serialized)
@MainActor
struct FloatFlickHeldTests {
    private static let window = WindowID(1)

    /// A core holding one window at `frame` in `mode`, its last
    /// write of the window half a second old, inside the 1 s
    /// grace; nil where the host has no screen.
    private func makeCore(
        mode: LayoutMode,
        frame: CGRect,
        written: Bool = true
    ) -> KiwiCore? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, mode)
        core.drag.settleDelay = 0.05
        if written {
            core.tiler.applyFrame(
                Self.window,
                from: frame,
                to: frame,
                animated: false
            )
            core.tiler.applier.clock = { 0.5 }
        }
        return core
    }

    private func start(_ screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX + 100,
            y: screen.frame.minY + 200,
            width: 400,
            height: 300
        )
    }

    /// A press on the window `age` seconds ago, still held.
    private func hold(_ core: KiwiCore, on frame: CGRect, age: Double) {
        core.mouse.seedPress(
            at: CGPoint(x: frame.midX, y: frame.minY + 10),
            downAt: core.wallClock().addingTimeInterval(-age)
        )
        core.mouse.pressedButtons = { 1 }
    }

    @Test(
        "a held move newer than our write opens the gesture",
        .enabled(if: NSScreen.main != nil),
        arguments: [
            (pressAge: 0.1, opens: true), (pressAge: 2.0, opens: false),
        ]
    )
    func heldMoveAnswersThePress(pressAge: Double, opens: Bool) throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = start(screen)
        let core = try #require(makeCore(mode: .floating, frame: frame))
        try #require(core.tiler.didRecentlySetFrame(Self.window))
        hold(core, on: frame, age: pressAge)

        core.handle(.windowMoved(Self.window, frame.offsetBy(dx: 0, dy: -20)))

        expectEqual(core.drag.hasGesture(Self.window), opens)
    }

    /// Every held move of the gesture answers the press, not only
    /// the first: the grace outlasts several moves.
    @Test(
        "a held gesture keeps its later moves",
        .enabled(if: NSScreen.main != nil)
    )
    func heldGestureKeepsLaterMoves() throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = start(screen)
        let core = try #require(makeCore(mode: .floating, frame: frame))
        hold(core, on: frame, age: 0.1)
        var moved = frame
        for _ in 1...3 {
            moved = moved.offsetBy(dx: 0, dy: -60)
            core.handle(.windowMoved(Self.window, moved))
        }
        #expect(core.drag.hasGesture(Self.window))
    }

    /// The control: a tile's held move inside the grace stays our
    /// echo (#1798's floats-only ruling).
    @Test(
        "a tile's held move stays our echo",
        .enabled(if: NSScreen.main != nil)
    )
    func tiledHeldMoveIsAnEcho() throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = start(screen)
        let core = try #require(makeCore(mode: .bsp, frame: frame))
        try #require(core.tiler.didRecentlySetFrame(Self.window))
        hold(core, on: frame, age: 0.1)

        core.handle(.windowMoved(Self.window, frame.offsetBy(dx: 0, dy: -20)))

        #expect(!core.drag.hasGesture(Self.window))
    }

    /// The button reads up before the release is recorded: a press
    /// under a second old counts as released now; an older one is
    /// no flick.
    @Test(
        "a release in flight counts as released, bounded by the press",
        .enabled(if: NSScreen.main != nil),
        arguments: [
            (pressAge: 0.2, opens: true), (pressAge: 1.5, opens: false),
        ]
    )
    func releaseInFlightCounts(pressAge: Double, opens: Bool) throws {
        let screen = try #require(NSScreen.screens.first)
        let frame = start(screen)
        let core = try #require(
            makeCore(mode: .floating, frame: frame, written: false)
        )
        core.mouse.seedPress(
            at: CGPoint(x: frame.midX, y: frame.minY + 10),
            downAt: core.wallClock().addingTimeInterval(-pressAge)
        )
        try #require(core.mouse.press?.upAt == nil)

        core.handle(.windowMoved(Self.window, frame.offsetBy(dx: 0, dy: -20)))

        expectEqual(core.drag.hasGesture(Self.window), opens)
    }
}
