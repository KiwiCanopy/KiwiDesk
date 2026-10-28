import AppKit

/// The one look of a Space Bar or App Bar badge: the count, the
/// `+n` and the sticky, floating and pocket badges. Its disc stays
/// opaque with a hairline rim, so it holds on glass, and the dim
/// ladder reaches its mark alone (#2722). A badge paints through
/// here and never sets its own `alphaValue`.
enum BarBadgeFace {
    /// The rim's width in points.
    static let rimWidth: CGFloat = 1
    /// The rim's share of white on dark glass and of black on light
    /// glass: it parts the disc from the glass it sits on, so the
    /// shelf's Fill picks it, never the disc (ui-designer, #2722).
    static let lightRimAlpha: CGFloat = 0.35
    static let darkRimAlpha: CGFloat = 0.25

    /// The rim of a disc of `fill` on a shelf of `shelfFill`; a
    /// shelf with no Fill takes the disc's own polarity.
    static func rim(on fill: NSColor, shelfFill: String) -> NSColor {
        let ground =
            KiwiShelf.hasColour(shelfFill) ? NSColor(kiwiHex: shelfFill) : fill
        return ground.wantsLightInk
            ? NSColor.white.withAlphaComponent(lightRimAlpha)
            : NSColor.black.withAlphaComponent(darkRimAlpha)
    }

    /// Paints `badge`'s opaque, rimmed disc in `fill` on a shelf of
    /// `shelfFill`.
    @MainActor
    static func disc(_ badge: NSView, fill: NSColor, shelfFill: String) {
        badge.alphaValue = 1
        badge.layer?.backgroundColor = fill.cgColor
        badge.layer?.borderWidth = rimWidth
        badge.layer?.borderColor =
            rim(on: fill, shelfFill: shelfFill).cgColor
    }

    /// Paints a count badge in `fill` with its number in `ink` at
    /// `inkAlpha`, the tier the item's ladder gives it.
    @MainActor
    static func paint(
        _ badge: NSTextField,
        fill: String,
        ink: String,
        inkAlpha: CGFloat,
        shelfFill: String
    ) {
        disc(badge, fill: NSColor(kiwiHex: fill), shelfFill: shelfFill)
        let color = NSColor(kiwiHex: ink)
        badge.textColor = color.withAlphaComponent(
            color.alphaComponent * inkAlpha
        )
    }
}
