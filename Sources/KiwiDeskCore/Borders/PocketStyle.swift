import CoreGraphics
import Foundation

/// The pocket's settings: the mark's colour (#2671), where the
/// pocket plate sits (#2680), and how many windows it holds
/// (#2678).
public struct PocketStyle: Sendable, Equatable {
    /// Pocket fill hex string; empty = automatic, the plate's
    /// mark ink (`.labelColor`), so it follows light and dark.
    public var color = ""

    /// One window, as 4.0.0 shipped, or several: the plate then
    /// stays on screen while it holds two (#2678).
    public var capacity = PocketCapacity.one

    /// The screen edge the pocket plate sits on.
    public var edge = AppBarEdge.bottom

    /// Where along `edge` the pocket plate's centre sits, in
    /// percent: 0 the left or top end, 100 the right or bottom.
    public var position: CGFloat = Self.defaultPosition {
        didSet { position = Self.clampPosition(position) }
    }

    static let defaultPosition: CGFloat = 82

    public init() {}

    static func clampPosition(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, min(value, 100)) : defaultPosition
    }
}

extension PocketStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case color
        case capacity
        case edge
        case position
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let d = Self()
        color =
            try container.decodeIfPresent(
                String.self,
                forKey: .color
            ) ?? d.color
        capacity =
            try container.decodeIfPresent(
                PocketCapacity.self,
                forKey: .capacity
            ) ?? d.capacity
        edge =
            try container.decodeIfPresent(
                AppBarEdge.self,
                forKey: .edge
            ) ?? d.edge
        // `didSet` does not fire in init.
        position = Self.clampPosition(
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .position
            ) ?? d.position
        )
    }
}

/// How many windows the pocket holds (#2678).
public enum PocketCapacity: String, Sendable, Codable, CaseIterable {
    case one, several
}
