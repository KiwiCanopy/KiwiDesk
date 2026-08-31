import AppKit

extension NSColor {
    /// Resolves state-mark color, or the adaptive fallback for
    /// the empty "Automatic" sentinel (#429). Distinct from
    /// `init(kiwiHex:)`, whose parse-fail fallback is the accent:
    /// empty means "adapt with appearance", not "broken", so it
    /// must land on the adaptive fallback, never the accent.
    static func mark(hex: String, fallback: NSColor) -> NSColor {
        hex.isEmpty ? fallback : NSColor(kiwiHex: hex)
    }

    /// Auto-contrasted black or white glyph color for mark fills (#429).
    var contrastingGlyph: NSColor {
        let c = usingColorSpace(.sRGB) ?? self
        let luminance =
            0.299 * c.redComponent
            + 0.587 * c.greenComponent
            + 0.114 * c.blueComponent
        return luminance > 0.6 ? .black : .white
    }

    /// Opaque sRGB shadow color for focus glow overlays
    /// (`BorderStyle.glowColor(from:)`, `BorderOverlay.ensureBackend`,
    /// #358, #533).
    static func kiwiGlow(hex: String) -> CGColor {
        let base = NSColor(kiwiHex: BorderStyle.glowColor(from: hex))
        let srgb = base.usingColorSpace(.sRGB) ?? base
        // sRGB-tagged on purpose: the consumer is a
        // colour-managed CALayer — packing these components into a
        // GenericRGB colour would gamma-shift the bloom off the
        // pinned `glowColor` derivation.
        return CGColor(
            srgbRed: srgb.redComponent,
            green: srgb.greenComponent,
            blue: srgb.blueComponent,
            alpha: 1
        )
    }

    /// Parses hex color string with fallback to controlAccentColor
    /// (`DragVisual.parseHex`).
    convenience init(kiwiHex hex: String) {
        guard let c = DragVisual.parseHex(hex) else {
            self.init(
                cgColor: NSColor.controlAccentColor.cgColor
            )!
            return
        }
        self.init(
            srgbRed: c.red,
            green: c.green,
            blue: c.blue,
            alpha: c.alpha
        )
    }
}
