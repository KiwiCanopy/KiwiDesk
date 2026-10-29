import KiwiDeskCore

/// What the pointer previews on Simple's Space cards (#2777).
enum SimplePreviewHover: Equatable {
    /// A bundled look, by name, painted over the draft.
    case look(String)
}

/// Simple's Space pictures (#2777): one reading of which look they
/// wear, and where a Space opens.
extension SettingsModel {
    /// The hover the pictures are drawing, nil when the hovered
    /// look is gone.
    var simplePreviewHover: SimplePreviewHover? {
        switch nav.simpleHover {
        case .look(let name) where hoveredLook(name) != nil:
            return .look(name)
        default:
            return nil
        }
    }

    /// The pointer entered or left `subject`; a leave clears only
    /// its own hover, since the next enter can arrive first.
    func hoverSimple(_ subject: SimplePreviewHover, inside: Bool) {
        if inside {
            nav.simpleHover = subject
        } else if nav.simpleHover == subject {
            nav.simpleHover = nil
        }
    }

    /// The draft as the preview draws it: with a hovered look
    /// painted on, its colors included.
    var simplePreviewSettings: TilingSettings {
        guard case .look(let name) = simplePreviewHover,
            let look = hoveredLook(name)
        else { return config.settings }
        return look.painted(over: config.settings)
    }

    private func hoveredLook(_ name: String) -> ShelfLook? {
        core.bundledLooks.first { $0.name == name }
    }

    /// Where `space` is placed now, by the runtime's own
    /// precedence: a pin to a missing screen carries the screen it
    /// falls back to, which need not be the main one.
    func simplePlacement(of space: SpaceID) -> SpacePlacement.Resolution? {
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
    /// the chip and the preview's offline caption share.
    func spacePinBadge(_ space: SpaceID) -> SpacePinBadge {
        SpacePinBadge.resolve(
            pin: config.spacePins[space],
            connectedFingerprints: Set(displays.map(\.fingerprint)),
            name: screenName
        )
    }

    /// "Pin offline"'s sentence, naming the screen the pin waits
    /// for and the one the Space opens on meanwhile — the same
    /// fallback the preview's map lights. The chip's hover and the
    /// preview's caption read this one.
    func offlinePinSentence(_ space: SpaceID) -> String {
        guard
            case .pinnedAbsent(let pin, let fallback) =
                simplePlacement(of: space)
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
