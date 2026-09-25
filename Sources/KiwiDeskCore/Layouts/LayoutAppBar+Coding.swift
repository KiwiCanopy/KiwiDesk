import CoreGraphics
import Foundation

/// `LayoutAppBar`'s sparse `Codable`: every override is optional,
/// so an absent key inherits the global (`AppBarParityTests`
/// reflects over `Key.allCases`; a new field joins it, the
/// decoder AND the encoder, or the round-trip reds).
extension LayoutAppBar: Codable {
    typealias CodingKeys = Key

    /// JSON coding keys for LayoutAppBar (`AppBarParityTests`).
    enum Key: String, CodingKey, CaseIterable {
        case enabled
        case activeIndicator = "active_indicator"
        case content
        case titleCap = "title_cap"
        case groupAdjacentWindows = "group_adjacent_windows"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        enabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .enabled
            ) ?? true
        activeIndicator = try container.decodeIfPresent(
            ActiveIndicator.self,
            forKey: .activeIndicator
        )
        content = try container.decodeIfPresent(
            Content.self,
            forKey: .content
        )
        titleCap = try container.decodeIfPresent(
            Int.self,
            forKey: .titleCap
        )
        groupAdjacentWindows = try container.decodeIfPresent(
            Bool.self,
            forKey: .groupAdjacentWindows
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(
            activeIndicator,
            forKey: .activeIndicator
        )
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(titleCap, forKey: .titleCap)
        try container.encodeIfPresent(
            groupAdjacentWindows,
            forKey: .groupAdjacentWindows
        )
    }
}
