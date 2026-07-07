import Foundation

/// The single space→display precedence (#36): explicit pin →
/// Main role → the positional default's plan (#53). Both the
/// runtime (`resolveSpaceDisplays`) and the GUI Canvas resolve
/// through this one pure function, so they cannot drift.
public enum SpacePlacement {
    /// How one space's display resolved.
    public enum Resolution: Equatable, Sendable {
        /// Pinned, and the pinned display is connected.
        case pinned(Display)
        /// Pinned to a disconnected display: placement falls
        /// back to `fallback`, while the fingerprint (the
        /// user's intent) is preserved for editing UIs.
        case pinnedAbsent(String, fallback: Display)
        /// Main role — follows the current main display.
        case main(Display)
        /// The positional default's plan, or main when the
        /// plan does not cover the space.
        case auto(Display)

        /// The display the space effectively lands on.
        public var display: Display {
            switch self {
            case .pinned(let display),
                .pinnedAbsent(_, fallback: let display),
                .main(let display),
                .auto(let display):
                return display
            }
        }
    }

    /// Resolves one space. `assignment` is the positional
    /// default's plan (`ProfileComposition.Composed`'s
    /// `assignment`), composed once by the caller. Nil only
    /// when no display is connected — otherwise resolution is
    /// total.
    public static func resolve(
        space: SpaceID,
        pins: [SpaceID: String],
        mainSpaces: Set<SpaceID>,
        displays: [Display],
        mainID: DisplayID?,
        assignment: [SpaceID: DisplayID]
    ) -> Resolution? {
        guard !displays.isEmpty else { return nil }
        let main =
            displays.first { $0.id == mainID }
            ?? PositionalDisplays.ordered(
                displays,
                mainID: mainID
            )[0]
        let unpinned = unpinnedResolution(
            space: space,
            mainSpaces: mainSpaces,
            displays: displays,
            main: main,
            assignment: assignment
        )
        guard let pin = pins[space] else { return unpinned }
        if let pinned = displays.first(where: {
            $0.fingerprint == pin
        }) {
            return .pinned(pinned)
        }
        return .pinnedAbsent(
            pin,
            fallback: unpinned.display
        )
    }

    /// Main role → the plan → main, for an unpinned space (and
    /// as the fallback behind a disconnected pin).
    private static func unpinnedResolution(
        space: SpaceID,
        mainSpaces: Set<SpaceID>,
        displays: [Display],
        main: Display,
        assignment: [SpaceID: DisplayID]
    ) -> Resolution {
        if mainSpaces.contains(space) { return .main(main) }
        if let assigned = assignment[space],
            let display = displays.first(where: {
                $0.id == assigned
            })
        {
            return .auto(display)
        }
        return .auto(main)
    }
}
