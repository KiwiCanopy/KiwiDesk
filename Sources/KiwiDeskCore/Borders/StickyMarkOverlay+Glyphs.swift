import AppKit

/// The plate's glyph images — the pocket's drawn by `PocketMark`
/// in its own colour (#2446, #2671) — split from
/// `StickyMarkOverlay` at the §2.1 ceiling. A symbol's tint is a
/// glyph's `symbolHex`, never its `color` (#2831).
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
}
