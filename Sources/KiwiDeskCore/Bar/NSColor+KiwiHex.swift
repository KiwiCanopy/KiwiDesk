import AppKit

extension NSColor {
    /// A state-mark tint (#429): the parsed hex, or an adaptive
    /// `fallback` (e.g. `.labelColor`) when the string is EMPTY —
    /// the "Automatic" sentinel that has no fixed hex. Distinct
    /// from `init(kiwiHex:)`, whose parse-fail fallback is the
    /// accent color: an empty mark color means "adapt with
    /// appearance", not "broken", so it must land on the adaptive
    /// fallback, never the accent. Shared by the sticky chip, both
    /// Space Bar state badges, and the Lua/CLI setters so every
    /// path resolves "Automatic" identically.
    static func mark(hex: String, fallback: NSColor) -> NSColor {
        hex.isEmpty ? fallback : NSColor(kiwiHex: hex)
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
