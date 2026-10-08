import AppKit

/// The shelf's font, as every bar text site asks for it (#1681).
extension KiwiShelf {
    /// Bar text — an identifier, a title — at `size`.
    @MainActor
    public func textFont(ofSize size: CGFloat) -> NSFont {
        BarFont.font(
            family: fontFamily,
            weight: resolvedFontWeight,
            size: size
        )
    }

    /// Bar text at `size` at a weight of its own, the shelf's
    /// family kept — a header that must out-weigh the text beneath
    /// it, as the hover peek's app line does (#1946).
    @MainActor
    public func textFont(
        ofSize size: CGFloat,
        emphasis: BarFontWeight
    ) -> NSFont {
        BarFont.font(family: fontFamily, weight: emphasis.value, size: size)
    }

    /// A count badge at `size`: the shelf's family at the badge's
    /// own `emphasis`, since a count must out-weigh the text it
    /// counts. A chosen family's digits are tabular so a count
    /// keeps its width; the system pair keeps today's glyphs.
    @MainActor
    public func badgeFont(
        ofSize size: CGFloat,
        emphasis: BarFontWeight
    ) -> NSFont {
        BarFont.font(
            family: fontFamily,
            weight: emphasis.value,
            size: size,
            tabularDigits: true
        )
    }

    /// What the shelf's family draws for its weight.
    @MainActor
    public var fontRendering: BarFont.Rendering {
        BarFont.rendering(family: fontFamily, weight: resolvedFontWeight)
    }
}
