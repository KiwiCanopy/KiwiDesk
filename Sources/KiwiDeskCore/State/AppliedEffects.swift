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

    /// Snapshot of facts erased when destroying a tracked window (#674).
    struct RemovedWindow: Sendable {
        let app: String?
        let bundleID: String?
        let space: SpaceID?
        let focusLost: Bool
        /// Window index in tiled slot order prior to removal (#674).
        let tiledSlot: Int?
    }
}
