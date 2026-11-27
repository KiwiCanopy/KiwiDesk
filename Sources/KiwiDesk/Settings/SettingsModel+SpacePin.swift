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
            pins: resolvedPins,
            mainSpaces: config.mainSpaces,
            displays: displays,
            mainID: PositionalDisplays.liveMainID,
            assignment: placementAssignment()
        )
    }

    /// A Space's Screen pin as its chip draws it: the one reading
    /// every pin chip takes.
    func spacePinBadge(_ space: SpaceID) -> SpacePinBadge {
        if waitingPins[space] != nil { return .offline }
        return SpacePinBadge.resolve(
            pin: pin(of: space),
            connectedFingerprints: Set(displays.map(\.fingerprint)),
            name: screenName
        )
    }

    /// "Pin offline"'s sentence, naming the screen the pin waits
    /// for and the one the Space opens on meanwhile — the runtime's
    /// own fallback. The chip's hover reads this one.
    func offlinePinSentence(_ space: SpaceID) -> String {
        if let number = waitingPins[space],
            let fallback = spacePlacement(of: space)?.display
        {
            return L(
                "spaces.pin_offline_badge.help_numbered",
                "Pinned to Screen %1$d, which isn't connected. Opens "
                    + "on %2$@ until it's back.",
                number,
                screenLabel(fallback)
            )
        }
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

    /// The offline chip's label: "Screen N offline" for a pin to a
    /// number no connected screen holds (#3647).
    func offlinePinLabel(_ space: SpaceID) -> String {
        guard let number = waitingPins[space] else {
            return L("spaces.pin_offline_badge", "Pin offline")
        }
        return offlinePinLabel(number: number)
    }

    /// The chip's and the Screen menu's words for a pin waiting on
    /// `number` (#3689).
    func offlinePinLabel(number: Int) -> String {
        L(
            "spaces.pin_offline_badge.numbered",
            "Screen %1$d offline",
            number
        )
    }

    /// The pinned chip's hover: the number and the screen holding it
    /// here, where the pin is a number this order holds (#3647).
    func pinnedHelp(_ space: SpaceID, _ displayName: String) -> String {
        guard let slot = config.spacePins[space], screenOrder.holds(slot)
        else {
            return L(
                "spaces.pin_badge.help",
                "Pinned to %1$@ for this profile.",
                displayName
            )
        }
        return L(
            "spaces.pin_badge.help_numbered",
            "Pinned to Screen %1$d, which is %2$@ here.",
            slot.number,
            displayName
        )
    }
}
