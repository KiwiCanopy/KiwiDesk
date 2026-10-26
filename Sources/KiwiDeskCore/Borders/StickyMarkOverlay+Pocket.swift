import AppKit

/// The pocket's glyph on the mark plate and its place half over
/// the window's corner (#2446), split from `StickyMarkOverlay` at
/// the §2.1 ceiling.
extension StickyMarkOverlay {
    /// The pocket mark, outlined in the plate's ink.
    static func pocketImage() -> NSImage {
        let image = PocketMark.mark.image(size: 14, ink: .labelColor)
        image.accessibilityDescription = L(
            "pocket.mark.ax",
            "Pocket window"
        )
        return image
    }

    /// The pocket mark sits half over the window's top-right
    /// corner, slid inward where a screen edge would cut it. AX
    /// coordinates.
    static func overCorner(
        of frame: CGRect,
        width: CGFloat
    ) -> CGRect {
        var mark = CGRect(
            x: frame.maxX - width / 2,
            y: frame.minY - size / 2,
            width: width,
            height: size
        )
        let corner = CGPoint(x: frame.maxX - 1, y: frame.minY + 1)
        guard
            let screen = ScreenList.all
                .map({ GeometryUtils.axVisibleFrame(of: $0) })
                .first(where: { $0.contains(corner) })
        else { return mark }
        mark.origin.x = min(mark.minX, screen.maxX - width)
        mark.origin.y = max(mark.minY, screen.minY)
        return mark
    }
}
