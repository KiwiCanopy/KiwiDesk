import CoreGraphics
import Foundation

/// The pocket's style: the mark's colour (#2671). Where it sits and
/// when it shows are KiwiShelf's (`pocketEdge`, `pocketPosition`,
/// `pocketVisibility`; #2678, #2978).
public struct PocketStyle: Sendable, Equatable {
    /// Pocket fill hex string; empty = automatic, the plate's
    /// mark ink (`.labelColor`), so it follows light and dark.
    public var color = ""

    public init() {}
}

extension PocketStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? Self().color
    }
}
