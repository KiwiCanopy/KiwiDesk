import AppKit

/// A bar title's fixed slot (#2086, #2545, owner rulings): a title
/// draws in a slot as long as the title cap in the bar font's
/// average glyph, so a title change moves no frame — a longer
/// title cuts with "…", a shorter one starts at the slot's start.
/// The Space Bar's front-app name and every App Bar item take it.
@MainActor
public enum BarTitleSlot {
    /// The slot's length for `cap` characters in `font`: the
    /// average lowercase glyph times the cap, the ellipsis past it,
    /// and the label's own cell padding. Memoized per face and cap.
    public static func length(cap: Int, font: NSFont) -> CGFloat {
        let key = SlotKey(
            font: font.fontName,
            size: font.pointSize,
            cap: cap,
            fonts: BarFont.generation
        )
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

    /// Where a title draws inside its slot: from the slot's start,
    /// right after the icon, whether it fits or is cut with "…", so
    /// every title starts at one offset and a short one leaves the
    /// trailing end empty (#2587). `natural` is the fitted width.
    static func span(
        natural: CGFloat,
        slotStart: CGFloat,
        slot: CGFloat
    ) -> ClosedRange<CGFloat> {
        slotStart...(slotStart + min(natural, slot))
    }

    /// The width `sizeToFit` gives `text` in `font` — the label's
    /// own cell, padding included.
    private static func titleWidth(_ text: String, font: NSFont) -> CGFloat {
        measure.font = font
        measure.stringValue = text
        measure.sizeToFit()
        return measure.frame.width
    }

    /// Centred as every title label is: `.center` alone widens the
    /// cell by ~4 pt, which a natural field's slot would cut.
    private static let measure: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.alignment = .center
        return field
    }()

    private struct SlotKey: Hashable {
        let font: String
        let size: CGFloat
        let cap: Int
        /// A font-set change re-measures (`BarFont.invalidate`).
        let fonts: Int
    }

    private static var slots: [SlotKey: CGFloat] = [:]
}
