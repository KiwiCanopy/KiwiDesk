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
        case activeIndicator = "active_indicator"
        case content
        case titleCap = "title_cap"
        case groupAdjacentWindows = "group_adjacent_windows"
    }

    /// Decodes AppBarStyle falling back to defaults for missing keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let defaults = Self()
        activeIndicator =
            try container.decodeIfPresent(
                ActiveIndicator.self,
                forKey: .activeIndicator
            ) ?? defaults.activeIndicator
        content =
            try container.decodeIfPresent(
                Content.self,
                forKey: .content
            ) ?? defaults.content
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
    }
}
