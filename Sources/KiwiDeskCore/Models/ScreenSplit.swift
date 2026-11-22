import Foundation

/// One physical screen's split (#3517): its areas and the next id
/// to mint, stored per profile in `display_areas` keyed by the
/// screen's fingerprint. `nextID` only grows, so an id is never
/// minted twice on a screen, even after the highest area merged
/// away (ruling 21).
public struct ScreenSplit: Codable, Equatable, Sendable {
    public var areas: [ScreenArea]
    public var nextID: Int

    enum CodingKeys: String, CodingKey {
        case areas
        case nextID = "next_id"
    }

    public init(areas: [ScreenArea], nextID: Int? = nil) {
        self.areas = areas
        self.nextID = max(
            nextID ?? 0,
            (areas.map(\.id).max() ?? -1) + 1
        )
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            areas: try c.decode([ScreenArea].self, forKey: .areas),
            nextID: try c.decodeIfPresent(Int.self, forKey: .nextID)
        )
    }

    /// Whether this split leaves the screen whole.
    public var isWhole: Bool { areas.count <= 1 }
}
