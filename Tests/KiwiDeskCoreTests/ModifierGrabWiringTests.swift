import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The modifier grab over a real core (#2447): the tap's events
/// reach the window under the pointer, its frame is written and
/// fed to the drag pipeline as a held drag, the press the swallow
/// deafened is re-delivered, and the window's AX echoes are left
/// out while the grab writes it.
@Suite("Modifier grab wiring", .serialized)
@MainActor
struct ModifierGrabWiringTests {
    private static let window = WindowID(41)
    private static let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

    private final class Log {
        var moves: [(start: CGRect, frame: CGRect)] = []
        var presses: [CGPoint] = []
    }

    private func make(_ log: Log) -> KiwiCore {
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: Self.window, pid: 900_041, appName: "App")
            )
        )
        core.state.apply(.windowMoved(Self.window, Self.frame))
        core.frontStack = {
            [
                KiwiCore.FrontWindow(
                    number: CGWindowID(Self.window.raw),
                    pid: 900_041,
                    layer: 0,
                    frame: Self.frame
                )
            ]
        }
        core.drag.onDragMove = { _, start, frame in
            log.moves.append((start, frame))
        }
        core.mouse.onLeftMouseDown = { point, _ in
            log.presses.append(point)
        }
        core.mouse.pointer.start()
        return core
    }

    private func send(
        _ core: KiwiCore,
        _ phase: ModifierGrabEvent.Phase,
        _ action: ModifierDragAction = .move,
        start: ModifierDragStart = .drag,
        at point: CGPoint
    ) {
        core.mouse.pointer.receive(
            PointerTapDelivery(
                grab: [
                    ModifierGrabEvent(
                        phase: phase,
                        action: action,
                        start: start,
                        location: point,
                        time: 0
                    )
                ],
                reenabled: false
            )
        )
    }

    @Test("bootstrap wires the grab and its log")
    func wired() {
        let core = make(Log())
        // A wired consumer with its default chords asks for the tap.
        var asked: [CGEventMask] = []
        core.mouse.pointer.makeTap = { mask, _ in
            asked.append(mask)
            return nil
        }
        core.mouse.pointer.stop()
        core.mouse.pointer.start()
        #expect(asked == [PointerConsumers.grabMask])
    }

    @Test("a move grab feeds the drag pipeline the moved frame")
    func moveFeedsTheDrag() throws {
        let log = Log()
        let core = make(log)
        let grab = CGPoint(x: 200, y: 150)
        send(core, .began, at: grab)
        #expect(core.modifierGrabOwns(Self.window))
        // The swallowed press reaches its listeners, in Cocoa space.
        #expect(log.presses == [GeometryUtils.axPoint(grab)])
        #expect(core.mouse.press != nil)
        send(core, .moved, at: CGPoint(x: 230, y: 170))
        let move = try #require(log.moves.last)
        #expect(move.start == Self.frame)
        #expect(move.frame == Self.frame.offsetBy(dx: 30, dy: 20))
        #expect(core.drag.hasGesture(Self.window))
        #expect(core.mouse.leftButtonHeld)
        send(core, .ended, at: CGPoint(x: 240, y: 170))
        #expect(!core.modifierGrabOwns(Self.window))
        #expect(!core.mouse.leftButtonHeld)
        #expect(core.mouse.press?.upAt != nil)
    }

    @Test("a resize grab moves the edges nearest the grab")
    func resizeFeedsTheDrag() throws {
        let log = Log()
        let core = make(log)
        // Bottom-right cell: the bottom-right corner.
        send(core, .began, .resize, at: CGPoint(x: 480, y: 390))
        send(core, .moved, .resize, at: CGPoint(x: 500, y: 400))
        let move = try #require(log.moves.last)
        #expect(
            move.frame == CGRect(x: 100, y: 100, width: 420, height: 310)
        )
    }

    @Test("a hover grab re-delivers no press")
    func hoverTakesNoPress() {
        let log = Log()
        let core = make(log)
        send(core, .began, start: .hover, at: CGPoint(x: 200, y: 150))
        #expect(core.modifierGrabOwns(Self.window))
        #expect(log.presses.isEmpty)
        #expect(core.mouse.leftButtonHeld)
    }

    @Test("the window's AX echoes are left out while the grab writes")
    func echoesAreLeftOut() {
        let log = Log()
        let core = make(log)
        send(core, .began, at: CGPoint(x: 200, y: 150))
        send(core, .moved, at: CGPoint(x: 210, y: 150))
        let fed = log.moves.count
        // A lagging echo of an earlier write: fed to the
        // coordinator it reads as our animation and cancels the
        // gesture mid-grab.
        #expect(core.tiler.didRecentlySetFrame(Self.window))
        let stale = Self.frame.offsetBy(dx: 3, dy: 0)
        core.handle(.windowMoved(Self.window, stale))
        #expect(core.drag.hasGesture(Self.window))
        core.handle(
            .windowResized(
                Self.window,
                CGRect(x: 110, y: 100, width: 380, height: 280)
            )
        )
        #expect(core.drag.hasGesture(Self.window))
        #expect(log.moves.count == fed)
        // The next move still lands.
        send(core, .moved, at: CGPoint(x: 220, y: 150))
        #expect(log.moves.count == fed + 1)
    }

    @Test("an echo after the release is left out while the drop settles")
    func lateEchoIsLeftOut() {
        let log = Log()
        let core = make(log)
        send(core, .began, at: CGPoint(x: 200, y: 150))
        send(core, .moved, at: CGPoint(x: 240, y: 150))
        send(core, .ended, at: CGPoint(x: 260, y: 150))
        #expect(core.drag.hasGesture(Self.window))
        #expect(core.modifierGrabOwns(Self.window))
        core.handle(.windowMoved(Self.window, Self.frame))
        // Still settling, and not on the stale frame.
        #expect(core.drag.hasGesture(Self.window))
        #expect(log.moves.last?.frame == Self.frame.offsetBy(dx: 60, dy: 0))
        // Once the drop has settled, the window's next drag is its
        // own: the echo that opens it asks first, as the event arms
        // do, and the gesture it opens is never the grab's.
        core.drag.cancel(Self.window)
        #expect(!core.modifierGrabOwns(Self.window))
        core.drag.windowMoved(
            Self.window,
            frame: Self.frame,
            validated: true,
            answersPress: true
        )
        #expect(core.drag.hasGesture(Self.window))
        #expect(!core.modifierGrabOwns(Self.window))
    }

    @Test("nothing under the pointer takes no window")
    func nothingUnderThePointer() {
        let log = Log()
        let core = make(log)
        send(core, .began, at: CGPoint(x: 900, y: 900))
        #expect(core.modifierGrab.session == nil)
        send(core, .moved, at: CGPoint(x: 950, y: 950))
        #expect(log.moves.isEmpty)
    }
}
