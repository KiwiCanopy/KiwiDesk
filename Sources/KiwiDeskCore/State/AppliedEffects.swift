import Foundation

/// Computed side-effect facts returned by `StateCoordinator.apply`
/// (`KiwiCore+PreFold.swift`, #166, #1049 review).
public struct AppliedEffects: Sendable {
    /// Window removal metadata if event destroyed a tracked window.
    var removedWindow: RemovedWindow?

    /// Active space focus preceding a focus change (#152, #158).
    var focusBefore: WindowID?

    /// Whether float state flipped from remembered title override (#160).
    var floatFlipped = false

    /// Whether newly created window was deminiaturized (#40).
    var appearedWasMinimized = false

    /// Whether window returned to a remembered space assignment.
    var hadRememberedSpace = false

    /// Destination space if window was rehomed to active screen
    /// (`ArrivalScreenHomeTests`, #1010).
    var rehomedToScreenSpace: SpaceID?

    /// Whether the create paid a Desktop return's owed focus
    /// (`ReturningFocusFoldTests`, #1207).
    var paidReturningFocus = false

    /// Snapshot of facts erased when destroying a tracked window (#674).
    struct RemovedWindow: Sendable {
        let app: String?
        let bundleID: String?
        let space: SpaceID?
        let focusLost: Bool
        /// Window index in tiled slot order prior to removal
        /// (#674). Still scoped to the `focusLost` path, where the
        /// removed window WAS the active space's focused slot, so
        /// its home is the active space. The frame is no longer
        /// counterfactual outside that scope (#1225 derives it
        /// from the real active space rather than pretending the
        /// home space is active), but a background-space removal
        /// is now told honestly that a traveler renders
        /// elsewhere — which is not the row such a consumer is
        /// asking about either. Re-derive.
        let tiledSlot: Int?
    }
}
