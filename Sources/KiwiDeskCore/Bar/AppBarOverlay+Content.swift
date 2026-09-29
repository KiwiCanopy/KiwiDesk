import AppKit

/// Where the App run's drawn content sits — what the shelf's
/// section divider centres against (#1779).
extension AppBarOverlay {
    /// The span from the first item's drawn start to the last
    /// item's drawn end, in `root`'s coordinates, read at each
    /// item's target `frames` after it is configured; zero for
    /// no items.
    func drawnContent(
        frames: [CGRect],
        strip: CGRect,
        horizontal: Bool
    ) -> CGRect {
        guard let first = frames.first, let last = frames.last,
            let firstView = itemViews.first,
            itemViews.count == frames.count,
            let lastView = itemViews.last
        else { return .zero }
        let origin = { (frame: CGRect) in
            horizontal ? frame.minX : frame.minY
        }
        let start =
            origin(first)
            + firstView.drawnSpan(in: first.size).lowerBound
        let end =
            origin(last)
            + lastView.drawnSpan(in: last.size).upperBound
        let extent = max(end - start, 0)
        return horizontal
            ? CGRect(x: start, y: 0, width: extent, height: strip.height)
            : CGRect(x: 0, y: start, width: strip.width, height: extent)
    }
}
