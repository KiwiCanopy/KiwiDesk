import CoreGraphics
import Foundation

/// The Space Bar drag-drop state machine (#372).
///
/// A two-speed gesture, driven off the same AX drag signal the
/// rest of tiling uses (`DragCoordinator` → `onDragMove`/
/// `onDragEnd`):
///
/// - **Fast drop** — release on a Space item before the dwell
///   fires → relocate the window there, stay put (`move_to_space`).
/// - **Dwell** — hold over a Space item for `dwell` seconds → the
///   visible space springs to it; the drop is then an ordinary
///   in-space placement into the now-live layout.
///
/// The switch and the relocate are performed by injected closures
/// (KiwiCore), so this type stays AppKit-free and unit-testable.
@MainActor
final class SpaceBarDropCoordinator {
    /// What `ended` asks the driver to do.
    enum Outcome: Equatable {
        /// No bar target — hand back to the ordinary drag-end
        /// logic (same-space swap / snap-back).
        case none
        /// Fast drop onto a different space's item — relocate.
        case relocate(SpaceID)
        /// The space had already sprung; the window is on the
        /// now-visible target, so place it there with the
        /// ordinary in-space drop after re-homing its membership.
        case placeInSprung(SpaceID)
    }

    /// The dwell before a hover springs the space, read fresh at
    /// arm time so a live `space_bar.set_spring_delay` change takes
    /// effect on the next gesture with no cached-value staleness
    /// (#372). Injected so this type stays settings-free; the
    /// default is only a pre-wiring placeholder.
    var dwellProvider: @MainActor () -> TimeInterval = { 1.5 }

    /// Space whose item contains a Cocoa screen point, else nil.
    var hitTest: @MainActor (CGPoint) -> SpaceID? = { _ in nil }
    /// The window's current Space.
    var currentSpace: @MainActor (WindowID) -> SpaceID? = {
        _ in nil
    }
    /// Tint a space's item with the synthetic drag-hover (nil
    /// clears all).
    var setHover: @MainActor (SpaceID?) -> Void = { _ in }
    /// Start the pending-spring ring sweep on a space's item: it
    /// stays empty for `delay`, then fills over `fill`.
    var beginSweep:
        @MainActor (
            _ space: SpaceID, _ fill: TimeInterval,
            _ delay: TimeInterval
        ) -> Void = { _, _, _ in }

    /// Quiet time after entering an item before the sweep starts
    /// (#372 QA): a quick flick-to-relocate shows no loading ring.
    /// The spring still fires at the full dwell, so the sweep fills
    /// over `dwell - springPreDelay`; the dwell range floors above
    /// this so the sweep is always visible.
    static let springPreDelay: TimeInterval = 0.5

    /// Clear every hover tint and pending sweep.
    var clearFeedback: @MainActor () -> Void = {}
    /// Spring the visible space to `target` while `window` stays
    /// pinned mid-drag. Returns whether the spring actually
    /// happened — a refused sticky move (#445) or an already-active
    /// target springs nothing, so `fire` must not record it as
    /// `sprungSpace`.
    var spring:
        @MainActor (_ target: SpaceID, _ window: WindowID)
            -> Bool = { _, _ in false }

    /// The item currently armed (hover tint + running sweep), or
    /// nil. Lets `handleDragMove` suppress the in-space ghost
    /// while a bar target is armed.
    private(set) var armedSpace: SpaceID?
    /// The space this drag has already sprung into, if any.
    private(set) var sprungSpace: SpaceID?
    /// The window this gesture is dragging, or nil between
    /// gestures. Lets an abnormal drag end (window closed / tab
    /// rekeyed mid-drag) scope its teardown to the right window.
    private(set) var draggingWindow: WindowID?
    private var pendingDwell: Task<Void, Never>?

    #if DEBUG
        /// The pending spring's timeline, so a test can await the
        /// dwell instead of polling a clock for its effect (#994;
        /// `.claude/rules/tests.md` ▸ Async tests). Debug-only so
        /// a production read fails the release build rather than
        /// a review — `isArmed` is the in-flight predicate.
        ///
        /// What awaiting it does **not** mean. It is cleared the
        /// instant the dwell fires or is disarmed, so it is only
        /// readable while a spring is pending: read it afterwards
        /// and it is nil, whose `await` returns at once and
        /// asserts nothing. It also completes for a *cancelled*
        /// dwell, so it says the dwell ended, never that it
        /// sprang — that fact is `sprungSpace`.
        var dwellTask: Task<Void, Never>? { pendingDwell }
    #endif

    /// True while a bar target is armed pre-spring — the caller
    /// hides its own drag ghost/drop-zone then.
    var isArmed: Bool { armedSpace != nil }

    /// Feed every live drag move (button down).
    func moved(_ id: WindowID, cursor: CGPoint) {
        draggingWindow = id
        let target = hitTest(cursor)
        // A valid spring target is a bar item that is neither the
        // window's own space nor one we already sprang into.
        if let target,
            target != currentSpace(id),
            target != sprungSpace
        {
            guard target != armedSpace else { return }
            arm(target, id)
        } else if armedSpace != nil {
            disarm()
        }
    }

    /// Feed the settled drop. Returns what the driver should do;
    /// resets all gesture state.
    func ended(_ id: WindowID, cursor: CGPoint) -> Outcome {
        let sprung = sprungSpace
        disarm()
        sprungSpace = nil
        draggingWindow = nil
        if let sprung { return .placeInSprung(sprung) }
        if let target = hitTest(cursor),
            target != currentSpace(id)
        {
            return .relocate(target)
        }
        return .none
    }

    /// The gesture ended or was abandoned — drop all state.
    func reset() {
        disarm()
        sprungSpace = nil
        draggingWindow = nil
    }

    private func arm(_ target: SpaceID, _ id: WindowID) {
        // Clear the previously-armed item first: moving straight
        // from one Space item to another re-arms without a gap, and
        // the old item's ring sweep would otherwise keep animating
        // (#372 QA). Covers every bar/display.
        clearFeedback()
        armedSpace = target
        // Read the dwell once, so the ring sweep and the timer
        // that fires the spring share the exact same duration.
        let dwell = dwellProvider()
        let delay = min(Self.springPreDelay, dwell)
        setHover(target)
        beginSweep(target, dwell - delay, delay)
        pendingDwell?.cancel()
        pendingDwell = Task { [weak self] in
            let ns = UInt64(dwell * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.fire(target, id)
        }
    }

    private func disarm() {
        pendingDwell?.cancel()
        pendingDwell = nil
        armedSpace = nil
        clearFeedback()
    }

    private func fire(_ target: SpaceID, _ id: WindowID) {
        pendingDwell = nil
        armedSpace = nil
        clearFeedback()
        // Record the spring only if it actually switched: a refused
        // sticky move (#445) leaves the visible space put, so a
        // stale `sprungSpace` would suppress re-arming the pill and
        // mis-route the drop to `.placeInSprung` on the home space.
        if spring(target, id) {
            sprungSpace = target
        }
    }
}
