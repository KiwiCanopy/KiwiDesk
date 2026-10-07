import AppKit

/// Where a glyph's click menu opens against its peek (#1946).
extension BarPeekPanel {
    /// The top-left corner a `menu`-sized context menu takes so it
    /// meets the peek framed `peek` on the peek's BAR-SIDE edge —
    /// the edge nearest the item, where the press was — and grows
    /// away from the bar as the peek did, kept inside `visible`. In
    /// AppKit screen coordinates (y up), on whole points.
    nonisolated static func menuTopLeft(
        peek: CGRect,
        menu: CGSize,
        edge: AppBarEdge,
        visible screen: CGRect
    ) -> CGPoint {
        typealias M = BarPeekBody.Metrics
        var point: CGPoint
        switch edge {
        case .top, .left:
            point = CGPoint(x: peek.minX, y: peek.maxY)
        case .bottom:
            point = CGPoint(x: peek.minX, y: peek.minY + menu.height)
        case .right:
            point = CGPoint(x: peek.maxX - menu.width, y: peek.maxY)
        }
        let margin = M.screenMargin
        point.x = min(
            max(point.x, screen.minX + margin),
            max(screen.maxX - margin - menu.width, screen.minX + margin)
        )
        // The menu hangs down from its top-left corner.
        point.y = min(
            max(point.y, screen.minY + margin + menu.height),
            screen.maxY - margin
        )
        return CGPoint(x: point.x.rounded(), y: point.y.rounded())
    }
}
