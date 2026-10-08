import AppKit

/// The front-app segment's fixed length (#2086, owner ruling): its
/// name draws in a slot as long as the title cap in the bar font's
/// average glyph, so a focus change moves no frame — a longer name
/// cuts with "…", a shorter one sits inside.
extension SpaceBarOverlay {
    /// The slot's length for `cap` characters in `font`: the
    /// average lowercase glyph times the cap, the ellipsis past it,
    /// and the label's own cell padding. Memoized per face and cap.
    static func titleSlot(cap: Int, font: NSFont) -> CGFloat {
        let key = SlotKey(font: font.fontName, size: font.pointSize, cap: cap)
        if let known = slots[key] { return known }
        let padding = titleWidth("", font: font)
        let alphabet = "abcdefghijklmnopqrstuvwxyz"
        let average =
            (titleWidth(alphabet, font: font) - padding)
            / CGFloat(alphabet.count)
        let ellipsis = titleWidth("…", font: font) - padding
        let slot = ceil(average * CGFloat(cap) + ellipsis + padding)
        slots[key] = slot
        return slot
    }

    /// The slot `style` draws its front name in at `depth`.
    static func titleSlot(_ style: SpaceBarLook, depth: CGFloat) -> CGFloat {
        titleSlot(
            cap: style.bar.resolvedFrontAppTitleCap,
            font: style.shelf.textFont(
                ofSize: style.titleFontSize(forDepth: depth)
            )
        )
    }

    private struct SlotKey: Hashable {
        let font: String
        let size: CGFloat
        let cap: Int
    }

    private static var slots: [SlotKey: CGFloat] = [:]
}
