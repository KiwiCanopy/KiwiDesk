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

    /// The rim on `shelf`'s glass at `tier` of its strength, the
    /// dim the badge's mark takes. A shelf with no Fill draws glass
    /// that follows the Appearance pick, so `dark` — the badge's
    /// effective appearance — decides there. The threshold is
    /// `wantsLightInk`'s, `GlassTint.pin`'s, without its glass gate:
    /// a solid plate still paints the Fill.
    static func rim(
        on shelf: KiwiShelf,
        dark: Bool,
        tier: CGFloat = 1
    ) -> NSColor {
        let darkGround =
            KiwiShelf.hasColour(shelf.fillColor)
            ? NSColor(kiwiHex: shelf.fillColor).wantsLightInk : dark
        return darkGround
            ? NSColor.white.withAlphaComponent(lightRimAlpha * tier)
            : NSColor.black.withAlphaComponent(darkRimAlpha * tier)
    }

    /// Paints `badge`'s opaque disc in `fill` on `shelf`, its rim
    /// dimmed with its mark to `tier`.
    @MainActor
    static func disc(
        _ badge: NSView,
        fill: NSColor,
        shelf: KiwiShelf,
        tier: CGFloat
    ) {
        let dark =
            badge.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            == .darkAqua
        badge.alphaValue = 1
        badge.layer?.backgroundColor = fill.cgColor
        badge.layer?.borderWidth = rimWidth
        badge.layer?.borderColor =
            rim(on: shelf, dark: dark, tier: tier).cgColor
    }

    /// Paints a count badge in `fill` with its number in `ink` at
    /// `inkAlpha`, the tier the item's ladder gives it.
    @MainActor
    static func paint(
        _ badge: NSTextField,
        fill: String,
        ink: String,
        inkAlpha: CGFloat,
        shelf: KiwiShelf
    ) {
        disc(
            badge,
            fill: NSColor(kiwiHex: fill),
            shelf: shelf,
            tier: inkAlpha
        )
        let color = NSColor(kiwiHex: ink)
        badge.textColor = color.withAlphaComponent(
            color.alphaComponent * inkAlpha
        )
    }
}
