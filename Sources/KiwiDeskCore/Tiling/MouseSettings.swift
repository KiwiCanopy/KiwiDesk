import Foundation

/// Mouse pointer interaction settings (#186).
public struct MouseSettings: Sendable, Equatable, Codable {
    /// Warps pointer to center of newly-focused window (#186).
    public var followsFocus = false

    private enum CodingKeys: String, CodingKey {
        case followsFocus = "follows_focus"
    }

    public init() {}

    /// A profile saved before this key existed (or a
    /// hand-written partial object) keeps the missing default,
    /// matching `TilingSettings`' missing-keys contract.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        followsFocus =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .followsFocus
            ) ?? false
    }
}
