import KiwiDeskCore

/// Display pin badge resolution for space rows (#678 Phase 3).
/// The connected/offline split is the GUI face of
/// `SpacePlacement.Resolution.pinned` vs `.pinnedAbsent` — it
/// asks the placement resolver's own question, so the two cannot
/// disagree about whether a pin is live.
enum SpacePinBadge: Equatable {
    case none
    case pinned(displayName: String)
    case offline

    /// Resolves display pin status against connected display fingerprints.
    static func resolve(
        pin: String?,
        connectedFingerprints: Set<String>,
        name: (String) -> String
    ) -> SpacePinBadge {
        guard let pin, !pin.isEmpty else { return .none }
        return connectedFingerprints.contains(pin)
            ? .pinned(displayName: name(pin))
            : .offline
    }
}
