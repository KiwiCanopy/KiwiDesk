import Foundation

/// Composes the fallback layout when no saved profile matches
/// (#53). Resolution is TOTAL in both directions: every space
/// gets a screen and every screen gets content — extra screens
/// each receive one monocle space. There is deliberately no
/// near-match adaptation of user profiles.
public enum ProfileComposition {
    /// A fully resolved fallback layout for a live monitor set.
    public struct Composed: Sendable, Equatable {
        /// The Standard the composition is based on.
        public let sourceName: String
        /// Every defined space, in display order.
        public let spaces: [SpaceID]
        /// Mode per space (dense over `spaces`).
        public let spaceModes: [SpaceID: LayoutMode]
        /// Screen per space (dense over `spaces`).
        public let assignment: [SpaceID: DisplayID]
        public let settings: TilingSettings
    }

    /// Builds fallback composition for connected displays from closest
    /// Standard layout.
    public static func compose(
        displays: [Display],
        mainID: DisplayID?
    ) -> Composed? {
        guard
            let layout = StandardProfiles.standard(
                for: displays.count
            )
        else { return nil }
        return compose(
            layout: layout,
            displays: displays,
            mainID: mainID
        )
    }

    /// Composes specific built-in layout onto displays
    /// (`StandardLayout+Screens`).
    public static func compose(
        layout: StandardLayout,
        displays: [Display],
        mainID: DisplayID?
    ) -> Composed? {
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        guard !ordered.isEmpty, layout.spaceCount > 0 else {
            return nil
        }

        var spaces: [SpaceID] = []
        var modes: [SpaceID: LayoutMode] = [:]
        var assignment: [SpaceID: DisplayID] = [:]
        for space in layout.plannedSpaces {
            spaces.append(space)
            // Screen FIRST, so an unlisted mode is answered by
            // the display the space lands on rather than a fixed
            // `bsp` (owner ruling 2026-08-11); both sparse
            // fallbacks are the layout's own accessors
            // (`StandardLayout+Screens`).
            let position = layout.screen(
                of: space,
                screens: ordered.count
            )
            modes[space] = layout.mode(
                of: space,
                on: ScreenClass.of(ordered[position])
            )
            assignment[space] = ordered[position].id
        }
        var next = layout.spaceCount + 1
        for position in layout.screenCount..<ordered.count {
            let space = SpaceID(next)
            next += 1
            spaces.append(space)
            modes[space] = .monocle
            assignment[space] = ordered[position].id
        }
        return Composed(
            sourceName: layout.name,
            spaces: spaces,
            spaceModes: modes,
            assignment: assignment,
            settings: layout.settings
        )
    }
}
