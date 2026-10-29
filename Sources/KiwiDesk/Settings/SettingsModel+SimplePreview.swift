import KiwiDeskCore

/// What the pointer previews on Simple (#2737 ruling 9).
enum SimplePreviewHover: Equatable {
    case space(SpaceID)
    /// A bundled look, by name, painted over the draft.
    case look(String)
}

/// Simple's live preview (#2737 rulings 5 and 9): one reading of
/// which Space it shows, in which look, on which screen — the rows
/// and the preview column both ask here.
extension SettingsModel {
    /// The Space the preview shows: a hovered one, else the kept
    /// one, else the first. Nil with no Spaces.
    var simplePreviewSpace: SpaceID? {
        if case .space(let hovered) = simplePreviewHover {
            return hovered
        }
        return simpleKeptSpace
    }

    /// The Space the rows mark kept: the one a click kept while it
    /// is listed, else the first.
    var simpleKeptSpace: SpaceID? {
        if let kept = nav.simpleKept, config.spaces.contains(kept) {
            return kept
        }
        return config.spaces.first
    }

    /// Whether the preview shows what a click kept, rather than
    /// what the pointer is over — the frame's ring answers this.
    var simplePreviewIsKept: Bool { simplePreviewHover == nil }

    /// The hover the preview is drawing, nil when the hovered
    /// Space or look is gone.
    var simplePreviewHover: SimplePreviewHover? {
        switch nav.simpleHover {
        case .space(let space) where config.spaces.contains(space):
            return .space(space)
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

    /// The connected screen `space` opens on now — the map lights
    /// it, and the offline sentence names it.
    func simpleLanding(of space: SpaceID) -> Display? {
        simplePlacement(of: space)?.display
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
        let waiting = Display.fingerprintParts(pin).name
        guard fallback.id == mainDisplay?.id else {
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
