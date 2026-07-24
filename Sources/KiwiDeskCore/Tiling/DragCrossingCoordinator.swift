import CoreGraphics
import Foundation

/// Debounce + per-gesture bookkeeping for the live cross-display
/// "make-room" drag (#504).
///
/// While a tiled window is dragged, the cursor crossing onto a
/// display OTHER than the one its space lives on arms a dwell
/// timer; only when the cursor has stayed on that display for
/// `dwell` does `onCross` fire, and KiwiCore eager-moves the
/// window's membership there (the Space-Bar-spring model, #372,
/// keyed on displays). The dwell is the flip-flop guard: a cursor
/// skimming the display seam — or an overflow-inducing crossing
/// bouncing straight back — never re-tiles both displays per
/// mouse event; AX frame-sets are the slow path (AGENTS.md §5).
///
/// AppKit-free by injection (`displayAt`), like DragCoordinator:
/// tests place the cursor and describe displays without screens.
@MainActor
public final class DragCrossingCoordinator {
    /// How long the cursor must stay on a foreign display before
    /// the membership moves. Long enough to ride out a seam skim,
    /// short enough to read as immediate.
    public var dwell: TimeInterval = 0.15

    /// Resolves the display under a Cocoa (bottom-left) screen
    /// point. Wired to an NSScreen lookup in `wireDragCrossing`;
    /// injected so drag tests can fake a display topology.
    public var displayAt: @MainActor (CGPoint) -> DisplayID? = {
        _ in nil
    }

    /// Fired once per debounced crossing with the display the
    /// cursor settled on. KiwiCore re-checks eligibility there —
    /// state may have shifted during the dwell.
    var onCross: @MainActor (WindowID, DisplayID) -> Void = {
        _,
        _ in
    }

    /// What one drag gesture accumulated. Cleared by
    /// `endGesture` / `revertLiveCrossing` at drop or cancel.
    private struct Gesture {
        /// The window's home before the FIRST crossing — the
        /// abnormal-cancel restore point. Later crossings keep
        /// the original record.
        var originSpace: SpaceID?
        var originIndex = 0
        /// Whether any crossing actually moved membership this
        /// gesture. Read by the drop path to skip the resize
        /// interpretation (#492's clamp gotcha, live edition).
        var crossed = false
        /// A sticky refusal already flashed its pill this
        /// gesture; later dwell fires stay silent.
        var stickyRefused = false
    }
    private var gestures: [WindowID: Gesture] = [:]
    private var pending:
        (window: WindowID, display: DisplayID, task: Task<Void, Never>)?

    public init() {}

    /// Feed every live drag move. Schedules a dwell when the
    /// cursor sits on a display other than `homeDisplay`
    /// (the dragged window's current space's display), keeps an
    /// already-armed dwell for the SAME display running, and
    /// disarms when the cursor returns home or resolves nowhere.
    func moved(
        _ id: WindowID,
        cursor: CGPoint,
        homeDisplay: DisplayID?
    ) {
        guard
            let cursorDisplay = displayAt(cursor),
            let homeDisplay,
            cursorDisplay != homeDisplay
        else {
            cancelPending(for: id)
            return
        }
        if let pending, pending.window == id,
            pending.display == cursorDisplay
        {
            return
        }
        schedule(id, display: cursorDisplay)
    }

    /// Disarms a pending dwell for `id` (cursor back home, a
    /// Space Bar target armed, or the gesture stopped looking
    /// like a move).
    func cancelPending(for id: WindowID) {
        guard let pending, pending.window == id else { return }
        pending.task.cancel()
        self.pending = nil
    }

    /// Records the home to restore on an abnormal cancel. Only
    /// the FIRST crossing of a gesture writes it.
    func recordOriginIfNeeded(
        _ id: WindowID,
        space: SpaceID,
        index: Int
    ) {
        var gesture = gestures[id] ?? Gesture()
        guard gesture.originSpace == nil else { return }
        gesture.originSpace = space
        gesture.originIndex = index
        gestures[id] = gesture
    }

    /// The pre-crossing home, for the abnormal-cancel revert.
    func origin(for id: WindowID) -> (space: SpaceID, index: Int)? {
        guard let space = gestures[id]?.originSpace else {
            return nil
        }
        return (space, gestures[id]?.originIndex ?? 0)
    }

    func markCrossed(_ id: WindowID) {
        var gesture = gestures[id] ?? Gesture()
        gesture.crossed = true
        gestures[id] = gesture
    }

    /// Whether membership already moved displays this gesture.
    func hasCrossed(_ id: WindowID) -> Bool {
        gestures[id]?.crossed == true
    }

    func markStickyRefused(_ id: WindowID) {
        var gesture = gestures[id] ?? Gesture()
        gesture.stickyRefused = true
        gestures[id] = gesture
    }

    func stickyRefused(_ id: WindowID) -> Bool {
        gestures[id]?.stickyRefused == true
    }

    /// Ends the gesture at drop or cancel: disarms any dwell,
    /// forgets the bookkeeping, and reports whether the gesture
    /// ever crossed (the drop path's resize-gate bypass).
    @discardableResult
    func endGesture(_ id: WindowID) -> Bool {
        cancelPending(for: id)
        let crossed = gestures[id]?.crossed == true
        gestures[id] = nil
        return crossed
    }

    private func schedule(_ id: WindowID, display: DisplayID) {
        pending?.task.cancel()
        let task = Task { [weak self] in
            let ns = UInt64((self?.dwell ?? 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.fire(id, display: display)
        }
        pending = (id, display, task)
    }

    private func fire(_ id: WindowID, display: DisplayID) {
        guard let pending, pending.window == id,
            pending.display == display
        else { return }
        self.pending = nil
        onCross(id, display)
    }
}
