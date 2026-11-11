import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A modifier-grabbed float takes focus at its drop, as a tiled one
/// does (#2447, owner 2026-11-08 with ui-designer): no click reached
/// its app, so nothing else would focus it. A float dropped by its
/// own title bar is macOS's to focus and is left alone.
@Suite("Modifier grab drop focus", .serialized)
@MainActor
struct ModifierGrabFocusTests {
    private static let float = WindowID(51)
    private static let other = WindowID(52)
    private static let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

    /// A float under the pointer, with the focus on another window.
    private func make() throws -> KiwiCore {
        let core = makeTestCore()
        for id in [Self.float, Self.other] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 900_051, appName: "App")
                )
            )
        }
        core.focusWindow(Self.float, warp: false)
        #expect(core.execute("make_floating").isSuccess)
        core.state.apply(.windowMoved(Self.float, Self.frame))
        core.focusWindow(Self.other, warp: false)
        try #require(core.activeSpace?.focused == Self.other)
        core.frontStack = {
            [
                KiwiCore.FrontWindow(
                    number: CGWindowID(Self.float.raw),
                    pid: 900_051,
                    layer: 0,
                    frame: Self.frame
                )
            ]
        }
        core.mouse.pointer.start()
        return core
    }

    private func send(
        _ core: KiwiCore,
        _ phase: ModifierGrabEvent.Phase,
        at point: CGPoint
    ) {
        core.mouse.pointer.receive(
            PointerTapDelivery(
                grab: [
                    ModifierGrabEvent(
                        phase: phase,
                        action: .move,
                        start: .drag,
                        chord: [.control, .command],
                        location: point,
                        time: 0
                    )
                ],
                reenabled: false
            )
        )
    }

    @Test("a grabbed float is focused at its drop")
    func grabbedFloatTakesFocus() throws {
        let core = try make()
        send(core, .began, at: CGPoint(x: 200, y: 150))
        send(core, .moved, at: CGPoint(x: 240, y: 150))
        send(core, .ended, at: CGPoint(x: 240, y: 150))
        // The press itself moves no focus.
        #expect(core.activeSpace?.focused == Self.other)
        core.handleDragEnd(
            Self.float,
            start: Self.frame,
            frame: Self.frame.offsetBy(dx: 40, dy: 0)
        )
        #expect(core.focusedWindowID == Self.float)
    }

    @Test("a float dropped by its title bar keeps the focus macOS gave")
    func titleBarDropFocusesNothing() throws {
        let core = try make()
        core.handleDragEnd(
            Self.float,
            start: Self.frame,
            frame: Self.frame.offsetBy(dx: 40, dy: 0)
        )
        #expect(core.focusedWindowID == Self.other)
    }
}
