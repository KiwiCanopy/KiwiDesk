import Foundation

extension KiwiCore {
    /// The tie rule a directional step from `origin` over `tiled`
    /// hands the search (#2619): the last step's window for a
    /// focus, never a swap, then the first in `tiled`'s order —
    /// empty for a hop, whose landing Space's order means nothing
    /// from here; a nil origin (an empty Space) has no last step.
    /// A Floating `space` keeps the plain score: its windows are
    /// placed by hand, so no order or step back is meant.
    func navigationTie(
        from origin: WindowID?,
        tiled: [WindowID],
        in space: Space,
        swapping: Bool
    ) -> Navigation.TieBreak {
        guard space.mode != .floating else { return .none }
        return Navigation.TieBreak(
            returnTo: swapping
                ? nil : origin.flatMap(state.lastStep(before:)),
            order: Dictionary(
                tiled.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }
}
