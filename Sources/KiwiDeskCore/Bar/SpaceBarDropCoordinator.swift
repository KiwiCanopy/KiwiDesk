import CoreGraphics
import Foundation

/// Space Bar drag-drop state machine for fast relocate and spring hover
/// (#372).
@MainActor
final class SpaceBarDropCoordinator {
    /// What `ended` asks the driver to do.
    enum Outcome: Equatable {
        /// No bar target — hand back to ordinary drag-end logic.
        case none
        /// Fast drop onto a different space's item — relocate.
        case relocate(SpaceID)
        /// Drop into a space that already sprang visible during dwell.
        case placeInSprung(SpaceID)
    }

    /// Dwell duration provider before spring fires
    /// (`space_bar.set_spring_delay`, #372).
    var dwellProvider: @MainActor () -> TimeInterval = { 1.5 }

    /// Space whose item contains a Cocoa screen point, else nil.
    var hitTest: @MainActor (CGPoint) -> SpaceID? = { _ in nil }
    /// The window's current Space.
    var currentSpace: @MainActor (WindowID) -> SpaceID? = {
        _ in nil
    }
    /// Tint a space's item with synthetic drag-hover (nil clears all).
    var setHover: @MainActor (SpaceID?) -> Void = { _ in }
    /// Start pending-spring sweep on a space's item: (space, fill, delay).
    var beginSweep:
        @MainActor (
            _ space: SpaceID, _ fill: TimeInterval,
            _ delay: TimeInterval
        ) -> Void = { _, _, _ in }

    /// Quiet time after entering item before sweep starts (#372 QA).
    static let springPreDelay: TimeInterval = 0.5

    /// Clear hover tint and pending sweep.
    var clearFeedback: @MainActor () -> Void = {}
    /// Springs the visible space to `target` mid-drag. Returns
    /// whether the spring actually happened — a refused sticky
    /// move (#445) or an already-active target springs nothing,
    /// so `fire` must not record it as `sprungSpace`.
    var spring:
        @MainActor (_ target: SpaceID, _ window: WindowID)
            -> Bool = { _, _ in false }

    /// Armed space target (hover tint + active sweep).
    private(set) var armedSpace: SpaceID?
    /// Space already sprung during this drag.
    private(set) var sprungSpace: SpaceID?
    /// Dragged window in flight.
    private(set) var draggingWindow: WindowID?
    private var pendingDwell: Task<Void, Never>?

    #if DEBUG
        /// Pending dwell task for async test synchronization
        /// (#994; tests.md ▸ Async tests). Cleared the instant the
        /// dwell fires or disarms, and it also completes for a
        /// CANCELLED dwell — it says the dwell ended, never that
        /// it sprang; `sprungSpace` is that fact.
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
