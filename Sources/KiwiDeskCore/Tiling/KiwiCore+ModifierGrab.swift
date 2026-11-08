import AppKit
import CoreGraphics

/// One modifier grab in flight (#2447): the window it took, how,
/// and where it started. Held by `ModifierGrabState.session`.
struct ModifierGrabSession: Equatable {
    let id: WindowID
    let action: ModifierDragAction
    /// Whether a swallowed press started it, so its listeners are
    /// owed the press and the drags they did not hear.
    let pressed: Bool
    let start: CGRect
    let grab: CGPoint
    let handle: ModifierGrabGeometry.Handle
    var last: CGRect
}

/// What the modifier grab keeps between its events, written by
/// `KiwiCore+ModifierGrab` alone.
@MainActor
final class ModifierGrabState {
    /// The grab in flight, nil where none took a window.
    var session: ModifierGrabSession?
    /// The window the last grab released, whose drop the drag
    /// coordinator may still be settling.
    var released: WindowID?
}

/// The modifier grab's main-actor half (#2447): the tap decided
/// the phase; this finds the window, writes its frame and feeds
/// the drag pipeline through `DragCoordinator.windowMoved`, so the
/// ghost, the swap, the float clamp, the screen crossing and the
/// mouse resize are the title-bar drag's own, and
/// `windowMoveInFlight` answers true during a grab.
extension KiwiCore {
    /// Wires the consumer; once, at bootstrap.
    func wireModifierGrab() {
        mouse.pointer.setGrabHandler { [weak self] event in
            self?.withUserMotion { self?.handleModifierGrab(event) }
        }
    }

    func handleModifierGrab(_ event: ModifierGrabEvent) {
        switch event.phase {
        case .began: beginModifierGrab(event)
        case .moved:
            if let point = event.location { moveModifierGrab(to: point) }
        case .ended: endModifierGrab(event)
        }
    }

    /// Whether `id`'s AX echoes are a grab's own writes, which it
    /// already fed the pipeline: while it writes, and after its
    /// release until the drop settles, since a slow app's echo of
    /// an earlier write would land as the drop frame.
    func modifierGrabOwns(_ id: WindowID) -> Bool {
        modifierGrab.session?.id == id
            || (modifierGrab.released == id && drag.hasGesture(id))
    }

    private func beginModifierGrab(_ event: ModifierGrabEvent) {
        guard let point = event.location else { return }
        let pressed = event.start == .drag
        if pressed {
            // The swallowed press deafened the press record and
            // its fan-out; both are re-delivered through their
            // own doors (#2764 ruling).
            let cocoa = GeometryUtils.axPoint(point)
            mouse.deliverPress(at: cocoa, from: .otherApp)
            mouse.recordDown(at: cocoa, from: .otherApp, clickCount: 1)
        }
        modifierGrab.released = nil
        guard let window = frontTrackedWindow(at: point)?.window else {
            onLog("modifier drag: no window under the pointer")
            return
        }
        modifierGrab.session = ModifierGrabSession(
            id: window.id,
            action: event.action,
            pressed: pressed,
            start: window.frame,
            grab: point,
            handle: ModifierGrabGeometry.handle(
                at: point,
                on: window.frame
            ),
            last: window.frame
        )
        onLog("modifier drag: \(event.action.rawValue) w\(window.id.raw)")
    }

    private func moveModifierGrab(to point: CGPoint) {
        guard var session = modifierGrab.session else { return }
        let frame =
            session.action == .move
            ? ModifierGrabGeometry.moved(
                session.start,
                from: session.grab,
                to: point
            )
            : ModifierGrabGeometry.resized(
                session.start,
                handle: session.handle,
                from: session.grab,
                to: point
            )
        if session.pressed {
            // The swallowed drags never reached the bar reveal.
            shelves.reveal.moved(
                to: GeometryUtils.axPoint(point),
                dragging: true
            )
        }
        guard frame != session.last else { return }
        _ = tiler.applyFrame(
            session.id,
            from: session.last,
            to: frame,
            animated: false
        )
        session.last = frame
        modifierGrab.session = session
        drag.windowMoved(
            session.id,
            frame: frame,
            validated: true,
            answersPress: true,
            previous: session.start
        )
    }

    private func endModifierGrab(_ event: ModifierGrabEvent) {
        if let point = event.location { moveModifierGrab(to: point) }
        modifierGrab.released = modifierGrab.session?.id
        modifierGrab.session = nil
        // The drag coordinator settles the drop itself, now that
        // no grab holds the button down.
        if event.start == .drag { mouse.recordUp(from: .otherApp) }
    }
}
