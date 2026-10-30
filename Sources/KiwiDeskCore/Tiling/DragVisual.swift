import Foundation

/// One drag marker's switch (`drag.ghost`, `drag.drop_zone`). Its
/// look is fixed: the drop zone an untinted frosted plate, the ghost
/// a two-tone outline (#2797, `DragMarkerView`); the corners are
/// every window outline's, `TilingSettings.windowStroke` (#1742).
public struct DragVisual: Sendable, Equatable, Encodable {
    public var enabled: Bool

    /// The ghost, off for a fresh setup (#2797); a saved profile
    /// keeps the `enabled` it stored, since the struct encodes whole.
    public static let ghostDefault = DragVisual(enabled: false)

    /// The drop zone, on.
    public static let dropZoneDefault = DragVisual(enabled: true)

    public init(enabled: Bool) {
        self.enabled = enabled
    }

    /// Serialization coding keys.
    enum CodingKeys: String, CodingKey, CaseIterable {
        case enabled
    }

    /// Decodes the switch over `defaults` when absent.
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
