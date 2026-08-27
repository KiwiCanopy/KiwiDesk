import Foundation

/// The facts `StateCoordinator.apply` uniquely knows about an
/// event — captured as it folds the event in, because the write
/// erases them. `handle(_:)` reads these back to drive its
/// post-apply side effects instead of snapshotting state in a
/// pre-apply prologue (#166). One deliberate carve-out: a fact
/// the fold would only COPY out of state (the moved window's
/// pre-event frame, the gone window's pid) stays a pre-fold
/// read in `KiwiCore+PreFold.swift` — riding it here would
/// widen this hand-mirrored field list for a value the caller
/// can read one line earlier with no fold coupling (#1049
/// review). This struct is for facts the fold COMPUTES.
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

    /// `.windowCreated`: the arrival was homed to the space its
    /// own SCREEN shows instead of the one it remembered, which
    /// lays out on another screen (#1010) — the space it went
    /// to. Nil whenever the two agreed, which is every
    /// single-screen arrival.
    ///
    /// A DECISION rather than an erased fact, unlike its
    /// neighbours here, and it earns the field twice over: it
    /// is what `handle` narrates the cross-screen arrival from
    /// (a device trace cannot read the reason off the
    /// membership alone), and it is the seam
    /// `ArrivalScreenHomeTests` observes the ruling through —
    /// several of its stand-downs are visible in nothing else.
    var rehomedToScreenSpace: SpaceID?

    /// Facts a `.windowDestroyed` erases when it removes the
    /// window, snapshotted before the removal.
    struct RemovedWindow: Sendable {
        let app: String?
        let bundleID: String?
        let space: SpaceID?
        let focusLost: Bool
        /// The gone window's index among its space's effective
        /// tiled members, pre-removal; nil for a float or
        /// fullscreen member. The close handler re-derives the
        /// close-return jump distance from it, because after
        /// the fold the anchor `focusWindow` classifies from
        /// IS the pick (#674's arm sees distance zero).
        /// Scoped to the `focusLost` path: the index is framed
        /// with the home space as active (sticky-traveler
        /// injection follows focus), which matches reality
        /// only there — `focusLost` implies home == active. A
        /// consumer on a background-space removal inherits a
        /// counterfactual frame; re-derive instead.
        let tiledSlot: Int?
    }
}
