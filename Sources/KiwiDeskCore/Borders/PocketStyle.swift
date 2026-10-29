import CoreGraphics
import Foundation

/// The pocket's style: the mark's colour (#2671). Where it sits is
/// KiwiShelf's (`pocketEdge`, `pocketPosition`, #2678); how many
/// windows it holds is app-wide (`AppWideSettings.pocketCapacity`).
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

/// How many windows the pocket holds (#2678).
public enum PocketCapacity: String, Sendable, Codable, CaseIterable {
    case one, several
}
