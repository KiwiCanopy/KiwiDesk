import CoreGraphics

/// The pocket under One window on a bar's edge (#2793): it never
/// joins the shelf, so no bar moves for it. It stands at Position,
/// just inside the bars' strip on the window side, while a drag or a
/// play shows it.
extension KiwiCore {
    /// The One-window pocket's frame on `display` (AX) while a bar
    /// draws on the pocket's edge there; nil under Several, or where
    /// no bar's strip stands on that edge this pass.
    func pocketInsideFrame(on display: DisplayID) -> CGRect? {
        guard !pocketHoldsSeveral,
            let strip = pocketPlate.barStrips[display]
        else { return nil }
        let shelf = tiler.settings.kiwishelf
        return Self.pocketInsideFrame(
            strip: strip,
            edge: shelf.pocketEdge,
            position: shelf.pocketPosition,
            inner: shelf.innerMargin
        )
    }

    /// A square as deep as `strip`, `inner` past its window side, at
    /// `position` percent along it and kept within its length (AX).
    nonisolated static func pocketInsideFrame(
        strip: CGRect,
        edge: AppBarEdge,
        position: CGFloat,
        inner: CGFloat
    ) -> CGRect {
        let horizontal = edge.isHorizontal
        let side = horizontal ? strip.height : strip.width
        let low = horizontal ? strip.minX : strip.minY
        let high = horizontal ? strip.maxX : strip.maxY
        let share = max(0, min(position, 100)) / 100
        let start = min(
            max(low + (high - low) * share - side / 2, low),
            max(high - side, low)
        )
        switch edge {
        case .top:
            return CGRect(
                x: start,
                y: strip.maxY + inner,
                width: side,
                height: side
            )
        case .bottom:
            return CGRect(
                x: start,
                y: strip.minY - inner - side,
                width: side,
                height: side
            )
        case .left:
            return CGRect(
                x: strip.maxX + inner,
                y: start,
                width: side,
                height: side
            )
        case .right:
            return CGRect(
                x: strip.minX - inner - side,
                y: start,
                width: side,
                height: side
            )
        }
    }
}
