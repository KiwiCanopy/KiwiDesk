import CoreGraphics
import Foundation

/// AppBarStyle Decodable implementation and CodingKeys. The
/// `Codable` conformance stays in `AppBarStyle.swift` so encode
/// is synthesized there; a property absent from `CodingKeys` is
/// silently not encoded — `AppBarParityTests` is the net.
extension AppBarStyle {
    /// JSON keys are the Lua setters minus `set_`. `CaseIterable`
    /// is load-bearing — `AppBarParityTests` reflects over
    /// `allCases`; do not drop it as "unused".
    enum CodingKeys: String, CodingKey, CaseIterable {
        case edge
        case activeIndicator = "active_indicator"
        case titleCap = "title_cap"
        case groupAdjacentWindows = "group_adjacent_windows"
        case reserve
    }

    /// Decodes AppBarStyle falling back to defaults for missing keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? defaults.edge
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        titleCap =
            try container.decodeIfPresent(
                Int.self,
                forKey: .titleCap
            ) ?? defaults.titleCap
        groupAdjacentWindows =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .groupAdjacentWindows
            ) ?? defaults.groupAdjacentWindows
        reserve =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .reserve
            ) ?? defaults.reserve
    }
}
