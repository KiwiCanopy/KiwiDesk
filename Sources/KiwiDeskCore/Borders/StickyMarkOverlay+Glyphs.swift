import AppKit

/// The plate's glyph images — the pocket's drawn by `PocketMark`
/// (#2446, #2671) — and the pocket mark's place half over the
/// window's corner, split from `StickyMarkOverlay` at the §2.1
/// ceiling. A plate's tint is a glyph's `plateHex`, never its
/// `color`.
extension StickyMarkOverlay {
    /// The image `glyph` draws on the plate.
    static func image(_ glyph: StickyMarkManager.Glyph) -> NSImage? {
        if glyph.kind == .pocket {
            return pocketImage(hex: glyph.color)
        }
        let label =
            glyph.kind == .sticky
            ? L("sticky.mark.ax", "Sticky window")
            : L("floating.mark.ax", "Floating window")
        return NSImage(
            systemSymbolName: glyph.symbolName,
            accessibilityDescription: label
        )
    }

    /// The pocket mark in its colour `hex` (#2671).
    static func pocketImage(hex: String) -> NSImage {
        let image = PocketMark.mark.image(size: 14, hex: hex)
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
