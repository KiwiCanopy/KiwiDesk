import Foundation

/// Space-to-display placement resolution precedence (#36, #53).
public enum SpacePlacement {
    /// Resolution result for a space's display placement.
    public enum Resolution: Equatable, Sendable {
        /// Pinned to a connected display.
        case pinned(Display)
        /// Pinned to a disconnected display with fallback.
        case pinnedAbsent(intent: String, fallback: Display)
        /// Main role following active main display.
        case main(Display)
        /// Automatic assignment via positional plan.
        case auto(Display)

        /// The display the space effectively lands on.
        public var display: Display {
            switch self {
            case .pinned(let display),
                .pinnedAbsent(intent: _, fallback: let display),
                .main(let display),
                .auto(let display):
                return display
            }
        }
    }

    /// Resolves target display for a space (`ProfileComposition.Composed`).
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
            intent: pin,
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
