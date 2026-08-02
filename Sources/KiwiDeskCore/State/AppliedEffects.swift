import Foundation

/// The facts `StateCoordinator.apply` uniquely knows about an
/// event — captured as it folds the event in, because the write
/// erases them. `handle(_:)` reads these back to drive its
/// post-apply side effects instead of snapshotting state in a
/// pre-apply prologue (#166).
///
/// One flat struct, not an enum per event: the call site stays a
/// plain `let effects = state.apply(event)`, and every field is
/// nil / false unless the applied event produced it. The pure
/// classifiers (`WindowAppearReason`, `WindowGoneReason`) still
/// run in `handle()` — clock/AX-dependent composition stays in
/// wiring; only the raw facts move here.
public struct AppliedEffects: Sendable {
    /// A `.windowDestroyed` removed a tracked window, carrying
    /// the app and space the removal erased plus whether the
    /// gone window held the active space's focus (the fallback
    /// must then be raised). nil when the event removed nothing.
    var removedWindow: RemovedWindow?

    /// The active space's focus before a `.windowFocused` moved
    /// it — the intended target a stale self-echo must not
    /// revert (#152/#158). nil for every other event.
    var focusBefore: WindowID?

    /// A `.windowTitleChanged` flipped the window's float state
    /// by restoring a remembered override (#160) — the only
    /// title change that needs a retile.
    var floatFlipped = false

    /// `.windowCreated`: the id was in the minimized set, so
    /// this is a deminiaturize — classifies as `restored` (#40).
    var appearedWasMinimized = false

    /// `.windowCreated`: the window had a remembered space, so
    /// it returned from another native desktop or a restore.
    var hadRememberedSpace = false

    /// Facts a `.windowDestroyed` erases when it removes the
    /// window, snapshotted before the removal.
    struct RemovedWindow: Sendable {
        let app: String?
        let bundleID: String?
        let space: SpaceID?
        let focusLost: Bool
        /// The gone window was a transient overlay — a context
        /// menu, a panel, a launcher bar (#300's classification).
        let wasTransientOverlay: Bool

        /// Whether the removal owes the space's fallback a real
        /// focus handoff: an AX raise, and a pointer warp when
        /// mouse-follows-focus is on.
        ///
        /// Holding the focus is not enough — the window must
        /// also have been one the user meaningfully focused. A
        /// transient overlay never was (#671): macOS returns
        /// focus to whatever was underneath the moment the popup
        /// goes away, so our handoff adds nothing and costs a
        /// visible raise plus a mouse warp. Composed here rather
        /// than at the call site so the whole decision is
        /// reachable from a state-only test — the wiring's own
        /// `isListed` gate needs live AX.
        var handsOffFocus: Bool {
            focusLost && !wasTransientOverlay
        }
    }
}
