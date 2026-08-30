import CoreGraphics
import Foundation

/// Debounce and gesture bookkeeping for cross-display drag movement (#504,
/// #372).
@MainActor
public final class DragCrossingCoordinator {
    /// Dwell delay before cross-display window migration triggers (0.15s).
    public var dwell: TimeInterval = 0.15

    /// Resolves display ID under Cocoa screen point. Injected for unit
    /// testing.
    public var displayAt: @MainActor (CGPoint) -> DisplayID? = {
        _ in nil
    }

    /// Callback invoked when debounced display crossing fires.
    var onCross: @MainActor (WindowID, DisplayID) -> Void = {
        _,
        _ in
    }

    private struct Gesture {
        var originSpace: SpaceID?
        var originIndex = 0
        var crossed = false
        var stickyRefused = false
    }
    private var gestures: [WindowID: Gesture] = [:]
    /// A single slot, not per-window: only one window is ever
    /// user-dragged at a time, so `schedule` may displace another
    /// window's dwell without harm; `gestures` stays per-window
    /// because ids must not inherit stale bookkeeping.
    private var pending:
        (window: WindowID, display: DisplayID, task: Task<Void, Never>)?

    #if DEBUG
        /// Timeline handle for async crossing testing (#994;
        /// tests.md). Awaiting it does NOT mean a crossing fired —
        /// it also completes for a disarmed dwell, and it is nil
        /// when none is armed. `onCross` is the fact.
        var dwellTask: Task<Void, Never>? { pending?.task }
    #endif

    public init() {}

    /// Feeds live drag motion updates and schedules crossing dwell timer.
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

    /// Disarms pending dwell timer for `id`.
    func cancelPending(for id: WindowID) {
        guard let pending, pending.window == id else { return }
        pending.task.cancel()
        self.pending = nil
    }

    /// Records pre-crossing origin space and slot for abnormal revert (#504).
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

    /// Returns pre-crossing home space and index.
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

    /// Returns whether window crossed displays during current gesture (#492).
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

    /// Retargets gesture bookkeeping across native-tab rekeys (#308).
    func rekey(old: WindowID, new: WindowID) {
        cancelPending(for: old)
        guard let gesture = gestures.removeValue(forKey: old)
        else { return }
        gestures[new] = gesture
    }

    /// Ends gesture, cancels pending dwell, and reports if crossing occurred.
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
