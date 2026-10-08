import CoreGraphics
import Foundation

/// Debounces `windowMoved` events to detect user window drags and drops (#45).
@MainActor
public final class DragCoordinator {
    /// Fired once per finished drag with the gesture's start and
    /// final frames — the start frame is what tells a move (same
    /// size) from a resize, and it is the window's REAL size, not
    /// its slot: constrained apps never match their slot exactly.
    public var onDragEnd:
        @MainActor (WindowID, _ start: CGRect, _ end: CGRect)
            -> Void = { _, _, _ in }

    /// Fired for live user moves while mouse button is held.
    public var onDragMove:
        @MainActor (WindowID, _ start: CGRect, _ frame: CGRect)
            -> Void = { _, _, _ in }

    /// Filters out internal animation moves.
    public var isAnimating: @MainActor (WindowID) -> Bool = {
        _ in false
    }

    /// Mouse button pressed state check (injected for testing).
    public var isMousePressed: @MainActor () -> Bool = {
        false
    }

    /// Cursor location in Cocoa coordinates for drop target resolution (#492).
    public var cursorLocation: @MainActor () -> CGPoint = {
        .zero
    }

    /// Quiet time after last move event before drop is considered settled
    /// (seconds).
    public var settleDelay: TimeInterval = 0.35
    /// Recheck interval while waiting for mouse release.
    public var releasePollDelay: TimeInterval = 0.1

    private var pending: [WindowID: Task<Void, Never>] = [:]
    private var latestFrames: [WindowID: CGRect] = [:]
    /// First frame of in-flight gesture per window.
    private var startFrames: [WindowID: CGRect] = [:]
    /// Gestures opened by a move that arrived after the release
    /// (#1798): no live feedback ran, and their end owns no resize.
    private var lateOpened: Set<WindowID> = []

    public init() {}

    /// Whether a gesture on `id` is in flight — its first frame
    /// recorded and its settle not yet fired.
    public func hasGesture(_ id: WindowID) -> Bool {
        startFrames[id] != nil
    }

    /// Whether `id`'s gesture was opened late (`windowMoved`'s
    /// `late`), read by the drop and the resize classifier.
    public func isLateGesture(_ id: WindowID) -> Bool {
        lateOpened.contains(id)
    }

    /// Ingests a `windowMoved` event and schedules the debounce
    /// settle (#45). The gesture's start frame comes from
    /// `previous`, the caller's pre-event state: AX throttles move
    /// notifications, so a fast gesture's FIRST event already sits
    /// mid-flight — measuring from it loses everything before
    /// (#933: a fast border drag resized only part of the way).
    public func windowMoved(
        _ id: WindowID,
        frame: CGRect,
        validated: Bool = false,
        late: Bool = false,
        previous: CGRect? = nil
    ) {
        guard !isAnimating(id) else {
            cancel(id)
            return
        }
        if startFrames[id] == nil, !validated,
            !isMousePressed()
        {
            return
        }
        if startFrames[id] == nil, late { lateOpened.insert(id) }
        latestFrames[id] = frame
        let start = startFrames[id] ?? previous ?? frame
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

    #if DEBUG
        /// Pending settle task for async test synchronization
        /// (#994; tests.md ▸ Async tests). Awaiting it does NOT
        /// mean the drag ended: a settle finding the button still
        /// down reschedules itself, and after the drop it is nil,
        /// whose await returns at once. Assert on `onDragEnd`.
        func settleTask(for id: WindowID) -> Task<Void, Never>? {
            pending[id]
        }
    #endif

    /// Drops any pending drag for a window (it closed).
    public func cancel(_ id: WindowID) {
        pending[id]?.cancel()
        pending[id] = nil
        latestFrames[id] = nil
        startFrames[id] = nil
        lateOpened.remove(id)
    }

    private func settle(_ id: WindowID) {
        pending[id] = nil
        guard !isMousePressed() else {
            schedule(id, after: releasePollDelay)
            return
        }
        guard let frame = latestFrames[id] else {
            startFrames[id] = nil
            lateOpened.remove(id)
            return
        }
        let start = startFrames[id] ?? frame
        latestFrames[id] = nil
        startFrames[id] = nil
        onDragEnd(id, start, frame)
        lateOpened.remove(id)
    }
}
