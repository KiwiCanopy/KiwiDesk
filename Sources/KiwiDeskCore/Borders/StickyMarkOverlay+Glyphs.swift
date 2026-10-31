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
}
