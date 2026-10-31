import Foundation

/// The app's one hex colour parser (#2811).
public enum HexColor {
    /// sRGB components parsed from a hex color string.
    public struct RGBA: Sendable, Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double
    }

    /// Parses "#RRGGBB" / "#RRGGBBAA" (case-insensitive, the
    /// "#" optional) into sRGB components. Nil for anything
    /// else — command handlers use this to reject bad input.
    public static func parse(_ hex: String) -> RGBA? {
        var digits = hex
        if digits.hasPrefix("#") {
            digits = String(digits.dropFirst())
        }
        guard digits.count == 6 || digits.count == 8,
            let value = UInt64(digits, radix: 16)
        else { return nil }
        let hasAlpha = digits.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        return RGBA(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            alpha: hasAlpha
                ? Double(value & 0xFF) / 255
                : 1
        )
    }
}
