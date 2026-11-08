import AppKit
import CoreGraphics

/// One modifier grab in flight (#2447): the window it took, how,
/// and where it started. Held by `PointerConsumers.grabSession`.
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

    /// Whether a grab writes `id`'s frame now: its AX echoes are
    /// our own writes, which the grab already fed the pipeline.
    func modifierGrabOwns(_ id: WindowID) -> Bool {
        mouse.pointer.grabSession?.id == id
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
        guard let id = modifierGrabTarget(at: point),
            let window = state.windows[id]
        else {
            onLog("modifier drag: no window under the pointer")
            return
        }
        mouse.pointer.grabSession = ModifierGrabSession(
            id: id,
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
        onLog("modifier drag: \(event.action.rawValue) w\(id.raw)")
    }

    private func moveModifierGrab(to point: CGPoint) {
        guard var session = mouse.pointer.grabSession else { return }
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
        mouse.pointer.grabSession = session
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
        mouse.pointer.grabSession = nil
        // The drag coordinator settles the drop itself, now that
        // no grab holds the button down.
        if event.start == .drag { mouse.recordUp(from: .otherApp) }
    }

    /// The window a grab at `point` (AX space) takes: the front
    /// window there, tracked, not full screen, in a shown Space;
    /// nil over anything else — a bar, a menu, the Dock.
    func modifierGrabTarget(at point: CGPoint) -> WindowID? {
        guard state.windows.all.contains(where: { $0.frame.contains(point) })
        else { return nil }
        let own = getpid()
        guard
            let front = frontStack().first(where: {
                $0.frame.contains(point)
                    && !($0.pid == own
                        && Self.ignoresPointer(number: Int($0.number)))
            }),
            let window = state.windows[WindowID(front.number)],
            front.pid != own
                || eventLoop.tilesAsOwnWindow(
                    pid: window.pid,
                    id: window.id
                ),
            !window.isFullscreen,
            let space = state.stickyRenderSpace(of: window)
                ?? state.workspaces.space(of: window.id),
            state.workspaces.visibleSpaces.contains(space)
        else { return nil }
        return window.id
    }
}
