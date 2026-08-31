import Foundation

/// Border alignment options for drag visual strokes
/// (#754, `SettingsCodingTests`, `docs/design-decisions.md`).
public enum BorderAlignment: String, Sendable, Codable,
    Equatable, CaseIterable
{
    case inside
    case outside
}

/// Visual styling configuration for drag-and-drop ghost and drop-zone
/// indicators.
public struct DragVisual: Sendable, Equatable, Encodable {
    public var enabled: Bool
    public var border: Bool
    public var borderColor: String
    /// Stroke width in points (R6, #406).
    public var borderWidth: CGFloat
    public var borderAlignment: BorderAlignment
    public var fill: Bool
    public var fillColor: String

    /// Default ghost visual styling; the hue argument is
    /// re-derivable via
    /// `DragPairSeparationTests.ringHueFamilyCannotSeparateAtChroma`
    /// (`docs/accepted-limitations.md`, #511, #470, #578).
    /// Defaults mirrored in docs/lua-reference.md (drag colors) —
    /// change both.
    public static let ghostDefault = DragVisual(
        enabled: true,
        border: true,
        borderColor: "#347957",
        borderWidth: 5,
        borderAlignment: .inside,
        fill: true,
        fillColor: "#34795740"
    )

    /// Default drop zone visual styling (#511, `docs/lua-reference.md`).
    public static let dropZoneDefault = DragVisual(
        enabled: true,
        border: true,
        borderColor: "#C2790A",
        borderWidth: 5,
        borderAlignment: .inside,
        fill: true,
        fillColor: "#C2790A40"
    )

    public init(
        enabled: Bool,
        border: Bool,
        borderColor: String,
        borderWidth: CGFloat,
        borderAlignment: BorderAlignment,
        fill: Bool,
        fillColor: String
    ) {
        self.enabled = enabled
        self.border = border
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.borderAlignment = borderAlignment
        self.fill = fill
        self.fillColor = fillColor
    }

    /// Serialization coding keys (`CaseIterable` for palette reflection,
    /// #375).
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case border
        case borderColor = "border_color"
        case borderWidth = "border_width"
        case borderAlignment = "border_alignment"
        case fill
        case fillColor = "fill_color"
    }

    /// Decodes visual settings with fallback defaults for missing properties.
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
        borderWidth =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .borderWidth
            ) ?? defaults.borderWidth
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
