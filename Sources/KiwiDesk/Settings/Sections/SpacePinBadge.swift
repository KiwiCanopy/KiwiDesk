import KiwiDeskCore

/// Display pin badge resolution for space rows
/// (`SpacePlacement`, #678 Phase 3).
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
