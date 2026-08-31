import Foundation

/// Sticky window styling and indicator glyph configuration
/// (`Borders/StickyMarkManager`, `StickyMarkUngatedTests`, #414).
public struct StickyStyle: Sendable, Equatable {
    /// SF Symbol for global sticky windows (`infinity`, #414, #429).
    public static let symbolName = "infinity"

    /// SF Symbol for display-sticky windows
    /// (`pin.fill`, `⌃⌥P`, #445, #1094).
    public static let displaySymbolName = "pin.fill"

    /// Resolves indicator symbol name for given sticky scope.
    public static func symbolName(for scope: StickyScope) -> String? {
        switch scope {
        case .none: return nil
        case .global: return symbolName
        case .display: return displaySymbolName
        }
    }

    /// Whether on-window sticky mark is visible.
    public var mark = true

    /// Hex color string for sticky badge tint (#429).
    public var color = ""

    public init() {}
}

extension StickyStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case mark
        case color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        mark =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .mark
            ) ?? defaults.mark
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? defaults.color
    }
}
