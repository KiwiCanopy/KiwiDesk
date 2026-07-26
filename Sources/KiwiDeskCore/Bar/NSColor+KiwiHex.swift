import AppKit

extension NSColor {
    /// A state-mark tint (#429): the parsed hex, or an adaptive
    /// `fallback` (e.g. `.labelColor`) when the string is EMPTY —
    /// the "Automatic" sentinel that has no fixed hex. Distinct
    /// from `init(kiwiHex:)`, whose parse-fail fallback is the
    /// accent color: an empty mark color means "adapt with
    /// appearance", not "broken", so it must land on the adaptive
    /// fallback, never the accent. Shared by the sticky mark, both
    /// Space Bar state badges, and the Lua/CLI setters so every
    /// path resolves "Automatic" identically.
    static func mark(hex: String, fallback: NSColor) -> NSColor {
        hex.isEmpty ? fallback : NSColor(kiwiHex: hex)
    }

    /// A legible black-or-white glyph color for a symbol drawn on
    /// THIS color as a fill (#429): the state marks are filled
    /// discs, and the glyph on top is auto-contrasted rather than a
    /// second manual knob, so any picked fill keeps a readable mark
    /// (a guardrail on legibility, never on taste). Uses the sRGB
    /// relative-luminance weights, biased slightly toward white
    /// (threshold 0.6) since a mid-tone mark reads better with
    /// white than black. Alpha is ignored — the fill's own hue is
    /// what the glyph sits on.
    var contrastingGlyph: NSColor {
        let c = usingColorSpace(.sRGB) ?? self
        let luminance =
            0.299 * c.redComponent
            + 0.587 * c.greenComponent
            + 0.114 * c.blueComponent
        return luminance > 0.6 ? .black : .white
    }

    /// An opaque `CGColor` for the focus-border glow bloom
    /// (#358): the color is BRIGHTENED from the ring hue via
    /// `BorderStyle.glowColor(from:)` — a bloom is a fill, not a
    /// legibility-bound thin stroke, so it reads far more vivid
    /// than the darkened ring — and rebuilt with alpha forced
    /// to 1. Consumed only by `AppKitBorderOverlay`'s
    /// `CAShapeLayer` shadow: a glow ring always renders there,
    /// because the SkyLight window-backed context drops ANY
    /// shadow color to default black-at-low-alpha (#533 —
    /// device-confirmed regardless of the color's space; see
    /// `BorderOverlay.ensureBackend`). Used for the shadow color
    /// only — the ring body keeps its faithful hex (alpha
    /// included), so a translucent `focused_color` still reads
    /// translucent.
    static func kiwiGlow(hex: String) -> CGColor {
        let base = NSColor(kiwiHex: BorderStyle.glowColor(from: hex))
        let srgb = base.usingColorSpace(.sRGB) ?? base
        return CGColor(
            red: srgb.redComponent,
            green: srgb.greenComponent,
            blue: srgb.blueComponent,
            alpha: 1
        )
    }

    /// Colors come as user-set hex strings; a string that no
    /// longer parses falls back to the system accent color.
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
