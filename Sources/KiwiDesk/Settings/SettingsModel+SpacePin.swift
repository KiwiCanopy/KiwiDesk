import KiwiDeskCore

/// A Space's Screen pin as the pin chip reads it, on the Spaces
/// page and Simple's cards alike.
extension SettingsModel {
    /// Where `space` is placed now, by the runtime's own
    /// precedence: a pin to a missing screen carries the screen it
    /// falls back to, which need not be the main one.
    func spacePlacement(of space: SpaceID) -> SpacePlacement.Resolution? {
        SpacePlacement.resolve(
            space: space,
            pins: config.spacePins,
            mainSpaces: config.mainSpaces,
            displays: displays,
            mainID: PositionalDisplays.liveMainID,
            assignment: placementAssignment()
        )
    }

    /// A Space's Screen pin as its chip draws it: the one reading
    /// every pin chip takes.
    func spacePinBadge(_ space: SpaceID) -> SpacePinBadge {
        SpacePinBadge.resolve(
            pin: config.spacePins[space],
            connectedFingerprints: Set(displays.map(\.fingerprint)),
            name: screenName
        )
    }

    /// "Pin offline"'s sentence, naming the screen the pin waits
    /// for and the one the Space opens on meanwhile — the runtime's
    /// own fallback. The chip's hover reads this one.
    func offlinePinSentence(_ space: SpaceID) -> String {
        guard
            case .pinnedAbsent(let pin, let fallback) =
                spacePlacement(of: space)
        else {
            return L(
                "spaces.pin_offline_badge.help",
                "Pinned to a screen that isn't attached, so "
                    + "this Space opens on the main screen "
                    + "for now."
            )
        }
        return Self.offlinePinSentence(
            waiting: Display.fingerprintParts(pin).name,
            fallback: fallback,
            fallbackIsMain: fallback.id == mainDisplay?.id
        )
    }

    /// The sentence for a pin waiting on `waiting`, the Space
    /// opening on `fallback` meanwhile.
    static func offlinePinSentence(
        waiting: String,
        fallback: Display,
        fallbackIsMain: Bool
    ) -> String {
        guard fallbackIsMain else {
            return L(
                "spaces.pin_offline_badge.help_fallback",
                "Pinned to %1$@, which isn't connected.\nOpens on "
                    + "%2$@ until it's back.",
                waiting,
                fallback.name
            )
        }
        return L(
            "spaces.pin_offline_badge.help_named",
            "Pinned to %1$@, which isn't connected.\nOpens on %2$@, "
                + "the main screen, until it's back.",
            waiting,
            fallback.name
        )
    }
}
