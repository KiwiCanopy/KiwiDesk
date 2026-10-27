import Foundation

/// The pocket mark's style (#2671): its own colour, as the sticky
/// and floating marks each have theirs.
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
