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
    /// Fired once per finished drag with the final frame.
    public var onDragEnd: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// Filters out our own animation-driven move events.
    public var isAnimating: @MainActor (WindowID) -> Bool = {
        _ in false
    }

    /// Quiet time after the last move event (seconds).
    public var settleDelay: TimeInterval = 0.35

    private var pending: [WindowID: Task<Void, Never>] = [:]
    private var latestFrames: [WindowID: CGRect] = [:]

    public init() {}

    /// Feed every `windowMoved` event here.
    public func windowMoved(_ id: WindowID, frame: CGRect) {
        guard !isAnimating(id) else {
            // Our own animation: forget any pending drag so
            // a retile never counts as a user drop.
            pending[id]?.cancel()
            pending[id] = nil
            latestFrames[id] = nil
            return
        }
        latestFrames[id] = frame
        pending[id]?.cancel()
        let delay = settleDelay
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
    }

    private func settle(_ id: WindowID) {
        pending[id] = nil
        guard let frame = latestFrames[id] else { return }
        latestFrames[id] = nil
        onDragEnd(id, frame)
    }
}
