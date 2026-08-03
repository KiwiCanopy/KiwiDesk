import KiwiDeskCore

/// Which display-pin badge a space row shows (#678 Phase 3, turn
/// 8a). A space can be pinned to a specific display for the
/// profile; the row surfaces that as a badge so the pin is visible
/// without opening Monitors — and, when the pinned display is not
/// currently attached, says so rather than looking unpinned.
///
/// Pure over its inputs (no `SettingsModel`, no `L()`), so the
/// decision is unit-testable off the main actor and the row view
/// only maps the case to a `BadgeChip` and its localized string.
/// The connected/offline split is the GUI face of Core's
/// `SpacePlacement.Resolution.pinned` vs `.pinnedAbsent` — the row
/// asks the same question (is this pin's fingerprint among the
/// attached displays?) the placement resolver does, so the two
/// cannot disagree about whether a pin is live.
enum SpacePinBadge: Equatable {
    /// No display pin for this space — no badge.
    case none
    /// Pinned to an attached display, named for the badge.
    case pinned(displayName: String)
    /// Pinned to a display that is not currently attached.
    case offline

    /// `pin` is the space's stored display fingerprint (nil / empty
    /// when unpinned). `connectedFingerprints` is the set of
    /// attached displays' fingerprints; `name` resolves a
    /// fingerprint to its human display name for the badge.
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
