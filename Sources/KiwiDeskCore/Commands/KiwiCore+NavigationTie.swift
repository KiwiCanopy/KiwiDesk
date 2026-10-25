import Foundation

extension KiwiCore {
    /// The tie rule a directional step from `origin` over `tiled`
    /// hands the search (#2619): the last step's window for a
    /// focus, never a swap, then the first in `tiled`'s order.
    func navigationTie(
        from origin: WindowID,
        tiled: [WindowID],
        swapping: Bool
    ) -> Navigation.TieBreak {
        Navigation.TieBreak(
            returnTo: swapping ? nil : state.lastStep(before: origin),
            order: Dictionary(
                tiled.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }
}
