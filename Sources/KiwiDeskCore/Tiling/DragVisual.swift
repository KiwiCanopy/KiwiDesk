import Foundation

public enum BorderAlignment: String, Sendable, Codable, Equatable {
    case inside
    case outside
}

/// Style of one drag visual (ghost or drop zone): an on/off
/// switch plus an independently toggle-able border and fill,
/// each with its own hex color ("#RRGGBB" or "#RRGGBBAA").
public struct DragVisual: Sendable, Equatable, Encodable {
    public var enabled: Bool
    public var border: Bool
    public var borderColor: String
    public var borderThickness: CGFloat
    public var borderAlignment: BorderAlignment
    public var fill: Bool
    public var fillColor: String

    /// Ghost (drag origin): all kiwi-green — same hue as the
    /// focus accent. Origin vs. target reads by hue against the
    /// drop zone's amber (2026-07-20; was a brown/green swap, but
    /// brown left the palette with the moss-fill refresh).
    public static let ghostDefault = DragVisual(
        enabled: true,
        border: true,
        borderColor: "#4E9F3D",
        borderThickness: 5,
        borderAlignment: .inside,
        fill: true,
        fillColor: "#4E9F3D40"
    )

    /// Drop zone (drag target): all amber — the palette's other
    /// established hue (`focused_item_color`), so the target draws
    /// the eye apart from the green origin.
    public static let dropZoneDefault = DragVisual(
        enabled: true,
        border: true,
        borderColor: "#E8A33D",
        borderThickness: 5,
        borderAlignment: .inside,
        fill: true,
        fillColor: "#E8A33D40"
    )

    public init(
        enabled: Bool,
        border: Bool,
        borderColor: String,
        borderThickness: CGFloat,
        borderAlignment: BorderAlignment,
        fill: Bool,
        fillColor: String
    ) {
        self.enabled = enabled
        self.border = border
        self.borderColor = borderColor
        self.borderThickness = borderThickness
        self.borderAlignment = borderAlignment
        self.fill = fill
        self.fillColor = fillColor
    }

    /// `CaseIterable` so the palette color-key reflection
    /// (#375) can enumerate the two color keys the way it does
    /// for the bars; the `_color`-suffix filter picks them out.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case border
        case borderColor = "border_color"
        case borderThickness = "border_thickness"
        case borderAlignment = "border_alignment"
        case fill
        case fillColor = "fill_color"
    }

    /// Lenient decoding against the element's own defaults:
    /// keys missing from a profile keep the default look.
    public init(
        from decoder: Decoder,
        defaults: DragVisual
    ) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? defaults.enabled
        border =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .border
            ) ?? defaults.border
        borderColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .borderColor
            ) ?? defaults.borderColor
        borderThickness =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .borderThickness
            ) ?? defaults.borderThickness
        borderAlignment =
            try container.decodeIfPresent(
                BorderAlignment.self,
                forKey: .borderAlignment
            ) ?? defaults.borderAlignment
        fill =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .fill
            ) ?? defaults.fill
        fillColor =
            try container.decodeIfPresent(
                String.self,
                forKey: .fillColor
            ) ?? defaults.fillColor
    }

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
    public static func parseHex(_ hex: String) -> RGBA? {
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
