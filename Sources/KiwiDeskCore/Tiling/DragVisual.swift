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
    /// A *stroke* has a width; a *bar* has a thickness (R6/#406).
    /// The GUI already drew that distinction — its label is
    /// "Width" — and only the wire said `border_thickness`, so
    /// the wire moved to match rather than the other way round.
    public var borderWidth: CGFloat
    public var borderAlignment: BorderAlignment
    public var fill: Bool
    public var fillColor: String

    /// Ghost (drag origin): a deep emerald. It was the ring's
    /// yellow-green `#588613` until #511 measured origin against
    /// target and got **4.7/441** under simulated protanopia —
    /// worse than the 22 that #470 called "the same colour to a
    /// protanope". Target is locked (the drop-zone amber is the
    /// hex `space_bar.focusedItemColor` converged onto), so the
    /// origin had to move, and it could not stay a yellow-green:
    /// against that amber, nothing in the hue family separates
    /// while also clearing 3:1 on *both* near-white and near-black
    /// (`docs/accepted-limitations.md`). Hue ~150 is the nearest
    /// place both hold — 76/441, 5.2:1 and 4.0:1. So the ghost no
    /// longer matches the focus ring, deliberately: the ring has
    /// no partner to separate from and keeps `#588613`.
    /// Defaults mirrored in docs/lua-reference.md (drag colors)
    /// — change both.
    public static let ghostDefault = DragVisual(
        enabled: true,
        border: true,
        borderColor: "#347957",
        borderWidth: 5,
        borderAlignment: .inside,
        fill: true,
        fillColor: "#34795740"
    )

    /// Drop zone (drag target): a vivid, darkened amber — the
    /// other established hue, kept far from the emerald origin so
    /// the two read apart, including under red-green vision loss
    /// (#511). Darkened from the old #E8A33D for the same
    /// reason as the ring: legible over light window content.
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

    /// `CaseIterable` so the palette color-key reflection
    /// (#375) can enumerate the two color keys the way it does
    /// for the bars; the `_color`-suffix filter picks them out.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
        case border
        case borderColor = "border_color"
        case borderWidth = "border_width"
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
