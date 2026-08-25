import CoreGraphics
import Foundation

/// Detects the end of a user window drag.
///
/// AX only reports `windowMoved` — there is no "drag ended"
/// event — so a drag end is inferred by debouncing: when a
/// window stops emitting move events for `settleDelay`, the
/// drop happened. Frame updates caused by our own animations
/// are filtered out via `isAnimating`, and a gesture can only
/// start while the mouse button is down — programmatic moves
/// (apps repositioning their own windows, late AX echoes)
/// never count as drags (issue #45).
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

    /// The live pointer location in Cocoa (bottom-left) screen
    /// coordinates. Injected to keep this type AppKit-free and
    /// testable — drag tests place the cursor without moving the
    /// real mouse. Wired to `NSEvent.mouseLocation` in `wireDrag`.
    /// The drop target is keyed on this, not the dragged frame's
    /// center, so it reaches the destination display the instant
    /// the pointer does (#492).
    public var cursorLocation: @MainActor () -> CGPoint = {
        .zero
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
    ///
    /// `validated` marks events the caller already classified
    /// as part of a user gesture (the mouse-resize path, see
    /// KiwiCore.isResizeGesture). Unvalidated moves can only
    /// START a gesture while the mouse button is down: apps
    /// repositioning their own windows (a brand-new window
    /// right after the open) and AX echoes outliving the echo
    /// grace arrive with the button up, and reading them as
    /// drags swaps windows in the array and re-tiles them into
    /// the wrong slots (issue #45).
    ///
    /// `previous` is the frame the window had BEFORE this
    /// event (the caller's state, written by the last event).
    /// A gesture's start frame is taken from it, because AX
    /// throttles move/resize notifications: a fast gesture's
    /// FIRST event already sits mid-flight — or, released
    /// quickly, at the final frame — so measuring the gesture
    /// from that event's own frame loses everything before it
    /// (#933: a fast border drag resized only part of the
    /// way). Nil (or a first-ever event) falls back to the
    /// event frame, the old behavior.
    public func windowMoved(
        _ id: WindowID,
        frame: CGRect,
        validated: Bool = false,
        previous: CGRect? = nil
    ) {
        guard !isAnimating(id) else {
            // Our own animation: forget any pending drag so
            // a retile never counts as a user drop.
            pending[id]?.cancel()
            pending[id] = nil
            latestFrames[id] = nil
            startFrames[id] = nil
            return
        }
        // A real drag always emits its first move while the
        // button is still down; trailing events after the
        // release join the gesture already in flight.
        if startFrames[id] == nil, !validated,
            !isMousePressed()
        {
            return
        }
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
        /// The settle timeline pending for `id`, so a test can
        /// await the settle instead of polling a clock for its
        /// effect (#994; `.claude/rules/tests.md` ▸ Async tests).
        /// Debug-only so a production read fails the release
        /// build rather than a review: this is `schedule`'s
        /// bookkeeping, never a drag-in-flight predicate. This
        /// type publishes no such predicate — a site that needs
        /// one adds it rather than reaching for this.
        ///
        /// What awaiting it does **not** mean: that the drag
        /// ENDED. A settle finding the button still down
        /// reschedules itself on `releasePollDelay`, so a handle
        /// read mid-gesture completes its own poll leg having
        /// fired nothing; and after the drop it is nil, whose
        /// `await` returns at once and asserts nothing. Read it
        /// while the gesture under test is the one in flight,
        /// and assert on `onDragEnd`.
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
