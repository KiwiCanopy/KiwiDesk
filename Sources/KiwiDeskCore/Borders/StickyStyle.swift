import Foundation

/// Sticky window styling and indicator glyph configuration
/// (`Borders/StickyMarkManager`, `StickyMarkUngatedTests`, #414).
public struct StickyStyle: Sendable, Equatable {
    /// SF Symbol for global sticky windows (`infinity`, #414, #429).
    public static let symbolName = "infinity"

    /// SF Symbol for display-sticky windows (`pin.fill`, #445).
    /// A seeded keybinding is NAMED for this glyph (`⌃⌥P`, #1094):
    /// re-picking the symbol strands that letter's rationale in
    /// every catalog — re-pick it and re-argue the letter.
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

    /// Whether sticky windows reach across macOS Desktops
    /// (#1145): ∞ present on every Desktop, 📌 on its screen's.
    /// Inert without the bridge (`canDriveDesktops`); the
    /// `override_sticky_reach` per-window override outranks it.
    public var desktopReach = true

    public init() {}
}

extension StickyStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case mark
        case color
        case desktopReach = "desktop_reach"
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
        desktopReach =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .desktopReach
            ) ?? defaults.desktopReach
    }
}
