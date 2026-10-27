import CoreGraphics
import Foundation

/// The pocket's style: the mark's colour (#2671), and where the
/// brief pocket appears while a window goes in or out (#2680).
public struct PocketStyle: Sendable, Equatable {
    /// Pocket fill hex string; empty = automatic, the plate's
    /// mark ink (`.labelColor`), so it follows light and dark.
    public var color = ""

    /// The screen edge the brief pocket sits on.
    public var edge = AppBarEdge.bottom

    /// Where along `edge` the brief pocket's centre sits, in
    /// percent: 0 the left or top end, 100 the right or bottom.
    public var position: CGFloat = 82 {
        didSet { position = Self.clampPosition(position) }
    }

    public init() {}

    static func clampPosition(_ value: CGFloat) -> CGFloat {
        value.isFinite ? max(0, min(value, 100)) : 82
    }
}

extension PocketStyle: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case color
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
