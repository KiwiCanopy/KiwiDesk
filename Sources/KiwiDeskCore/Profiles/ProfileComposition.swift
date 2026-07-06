import Foundation

/// Composes the fallback layout when no saved profile matches
/// the connected monitors (#53).
///
/// Resolution is *total* in both directions: every space gets a
/// screen (positional default) and every screen gets content —
/// screens beyond the Standard's plan each receive one extra
/// monocle space (the honest "no plan yet" default). There is
/// deliberately no near-match adaptation of user profiles.
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

    /// Builds the fallback for the connected displays: the
    /// closest ≤N Standard, positionally mapped, plus one
    /// monocle space per uncovered extra screen. Nil only when
    /// no display is connected.
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

    /// Composes a specific built-in layout (a GUI Preset being
    /// applied, or the count's Standard) onto the connected
    /// displays, monocle-filling any screens beyond its plan.
    public static func compose(
        layout: StandardLayout,
        displays: [Display],
        mainID: DisplayID?
    ) -> Composed? {
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: mainID
        )
        guard !ordered.isEmpty else { return nil }

        var spaces: [SpaceID] = []
        var modes: [SpaceID: LayoutMode] = [:]
        var assignment: [SpaceID: DisplayID] = [:]
        for number in 1...layout.spaceCount {
            let space = SpaceID(number)
            spaces.append(space)
            modes[space] = layout.spaceModes[space] ?? .bsp
            // Positions are clamped defensively; a Standard
            // never plans beyond its own screen count.
            let position = min(
                layout.spaceScreens[space] ?? 0,
                ordered.count - 1
            )
            assignment[space] = ordered[position].id
        }
        // Monocle-fill: screens the Standard doesn't cover each
        // get one fresh space, numbered on after the last one.
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
