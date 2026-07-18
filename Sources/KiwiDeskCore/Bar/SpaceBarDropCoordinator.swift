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

    /// Dwell before a hover springs the space. Designer verdict
    /// (#372): 2.0s — longer than Finder's ~0.7s is right here
    /// because the ring-sweep shows progress and a space switch
    /// is a bigger disruption than a folder opening.
    var dwell: TimeInterval = 2.0

    /// Space whose item contains a Cocoa screen point, else nil.
    var hitTest: @MainActor (CGPoint) -> SpaceID? = { _ in nil }
    /// The window's current virtual space.
    var currentSpace: @MainActor (WindowID) -> SpaceID? = {
        _ in nil
    }
    /// Tint a space's item with the synthetic drag-hover (nil
    /// clears all).
    var setHover: @MainActor (SpaceID?) -> Void = { _ in }
    /// Start the pending-spring ring sweep on a space's item.
    var beginSweep: @MainActor (SpaceID, TimeInterval) -> Void = {
        _,
        _ in
    }
    /// Clear every hover tint and pending sweep.
    var clearFeedback: @MainActor () -> Void = {}
    /// Spring the visible space to `target` while `window` stays
    /// pinned mid-drag.
    var spring:
        @MainActor (_ target: SpaceID, _ window: WindowID)
            -> Void = { _, _ in }

    /// The item currently armed (hover tint + running sweep), or
    /// nil. Lets `handleDragMove` suppress the in-space ghost
    /// while a bar target is armed.
    private(set) var armedSpace: SpaceID?
    /// The space this drag has already sprung into, if any.
    private(set) var sprungSpace: SpaceID?
    private var dwellTask: Task<Void, Never>?

    /// True while a bar target is armed pre-spring — the caller
    /// hides its own drag ghost/drop-zone then.
    var isArmed: Bool { armedSpace != nil }

    /// Feed every live drag move (button down).
    func moved(_ id: WindowID, cursor: CGPoint) {
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
    }

    private func arm(_ target: SpaceID, _ id: WindowID) {
        armedSpace = target
        setHover(target)
        beginSweep(target, dwell)
        dwellTask?.cancel()
        dwellTask = Task { [weak self] in
            let ns = UInt64((self?.dwell ?? 2) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            self?.fire(target, id)
        }
    }

    private func disarm() {
        dwellTask?.cancel()
        dwellTask = nil
        armedSpace = nil
        clearFeedback()
    }

    private func fire(_ target: SpaceID, _ id: WindowID) {
        dwellTask = nil
        armedSpace = nil
        sprungSpace = target
        clearFeedback()
        spring(target, id)
    }
}
