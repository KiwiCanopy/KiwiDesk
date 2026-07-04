import CoreGraphics
import Foundation

/// Detects the end of a user window drag.
///
/// AX only reports `windowMoved` — there is no "drag ended"
/// event — so a drag end is inferred by debouncing: when a
/// window stops emitting move events for `settleDelay`, the
/// drop happened. Frame updates caused by our own animations
/// are filtered out via `isAnimating`.
@MainActor
public final class DragCoordinator {
    /// Fired once per finished drag with the frame at the
    /// gesture's start and the final frame. The start frame
    /// tells a move (same size) from a resize (size changed)
    /// — the window's real size, not its slot, because apps
    /// with size constraints never match their slot exactly.
    public var onDragEnd:
        @MainActor (WindowID, _ start: CGRect, _ end: CGRect)
            -> Void = { _, _, _ in }

    /// Fired for every user-driven move while the button is
    /// down — live feedback (drag ghost / drop zone), not
    /// debounced. Trailing AX events after the release only
    /// reach onDragEnd. Same (start, current) frame pair as
    /// onDragEnd.
    public var onDragMove:
        @MainActor (WindowID, _ start: CGRect, _ frame: CGRect)
            -> Void = { _, _, _ in }

    /// Filters out our own animation-driven move events.
    public var isAnimating: @MainActor (WindowID) -> Bool = {
        _ in false
    }

    /// Whether the user still holds the mouse button. A
    /// gesture can only end after the release: fast drags
    /// stop emitting AX moves long before the drop, and
    /// standing still mid-drag is not a drop either.
    /// Injected to keep this type AppKit-free and testable.
    public var isMousePressed: @MainActor () -> Bool = {
        false
    }

    /// Quiet time after the last move event (seconds).
    public var settleDelay: TimeInterval = 0.35
    /// Recheck interval while waiting for the release.
    public var releasePollDelay: TimeInterval = 0.1

    private var pending: [WindowID: Task<Void, Never>] = [:]
    private var latestFrames: [WindowID: CGRect] = [:]
    /// First frame of the gesture in flight, per window.
    private var startFrames: [WindowID: CGRect] = [:]

    public init() {}

    /// Feed every `windowMoved` event here.
    public func windowMoved(_ id: WindowID, frame: CGRect) {
        guard !isAnimating(id) else {
            // Our own animation: forget any pending drag so
            // a retile never counts as a user drop.
            pending[id]?.cancel()
            pending[id] = nil
            latestFrames[id] = nil
            startFrames[id] = nil
            return
        }
        latestFrames[id] = frame
        let start = startFrames[id] ?? frame
        startFrames[id] = start
        if isMousePressed() {
            onDragMove(id, start, frame)
        }
        schedule(id, after: settleDelay)
    }

    private func schedule(
        _ id: WindowID,
        after delay: TimeInterval
    ) {
        pending[id]?.cancel()
        pending[id] = Task { [weak self] in
            let ns = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.settle(id)
        }
    }

    /// Drops any pending drag for a window (it closed).
    public func cancel(_ id: WindowID) {
        pending[id]?.cancel()
        pending[id] = nil
        latestFrames[id] = nil
        startFrames[id] = nil
    }

    private func settle(_ id: WindowID) {
        pending[id] = nil
        guard !isMousePressed() else {
            schedule(id, after: releasePollDelay)
            return
        }
        guard let frame = latestFrames[id] else {
            startFrames[id] = nil
            return
        }
        let start = startFrames[id] ?? frame
        latestFrames[id] = nil
        startFrames[id] = nil
        onDragEnd(id, start, frame)
    }
}
