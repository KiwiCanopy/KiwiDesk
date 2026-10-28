import AppKit

/// The one look of a Space Bar or App Bar badge: the count, the
/// `+n` and the sticky, floating and pocket badges. Its disc stays
/// opaque with a hairline rim, so it holds on glass, and the dim
/// ladder reaches its mark alone (#2722). A badge paints through
/// here and never sets its own `alphaValue`.
enum BarBadgeFace {
    /// The rim's width in points.
    static let rimWidth: CGFloat = 0.5
    /// The rim's share of white on a dark disc and of black on a
    /// light one, so it reads on every palette's badge colour.
    static let lightRimAlpha: CGFloat = 0.14
    static let darkRimAlpha: CGFloat = 0.18

    /// The rim on a disc of `fill`.
    static func rim(on fill: NSColor) -> NSColor {
        fill.wantsLightInk
            ? NSColor.white.withAlphaComponent(lightRimAlpha)
            : NSColor.black.withAlphaComponent(darkRimAlpha)
    }

    /// Paints `badge`'s opaque, rimmed disc in `fill`.
    @MainActor
    static func disc(_ badge: NSView, fill: NSColor) {
        badge.alphaValue = 1
        badge.layer?.backgroundColor = fill.cgColor
        badge.layer?.borderWidth = rimWidth
        badge.layer?.borderColor = rim(on: fill).cgColor
    }

    /// Paints a count badge in `fill` with its number in `ink` at
    /// `inkAlpha`, the tier the item's ladder gives it.
    @MainActor
    static func paint(
        _ badge: NSTextField,
        fill: String,
        ink: String,
        inkAlpha: CGFloat
    ) {
        disc(badge, fill: NSColor(kiwiHex: fill))
        let color = NSColor(kiwiHex: ink)
        badge.textColor = color.withAlphaComponent(
            color.alphaComponent * inkAlpha
        )
    }
}
