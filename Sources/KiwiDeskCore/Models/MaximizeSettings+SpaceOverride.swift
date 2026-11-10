import Foundation

/// A Space's own Maximize Height and Width shares, either axis set
/// alone (`maximize.share_override`, #3090).
public struct MaximizeShareOverride: Codable, Sendable, Equatable {
    /// The width share of a Maximize Height in this Space.
    public var height: Double?
    /// The height share of a Maximize Width in this Space.
    public var width: Double?

    public init(height: Double? = nil, width: Double? = nil) {
        self.height = height
        self.width = width
    }

    public subscript(axis: MaximizeAxis) -> Double? {
        get {
            switch axis {
            case .height: height
            case .width: width
            }
        }
        set {
            switch axis {
            case .height: height = newValue
            case .width: width = newValue
            }
        }
    }

    /// Whether neither axis is set: the entry is dropped then.
    public var isEmpty: Bool { height == nil && width == nil }
}

/// The per-Space half of `MaximizeSettings` (#3090): a Space's own
/// share and anchor outrank its screen shape's row. These two
/// functions are the ONE precedence read — the press
/// (`KiwiCore.maximizeShape(from:for:)`) and `resolved(for:)` both
/// take them; a binding's own arguments still win at the press.
extension MaximizeSettings {
    /// The share a press of `axis` takes in `space` on a screen of
    /// `shape`: the Space's own value, else the shape's row.
    public func share(
        for axis: MaximizeAxis,
        on shape: ScreenShape,
        in space: SpaceID?
    ) -> Double {
        space.flatMap { shareOverride[$0]?[axis] }
            ?? share(for: axis, on: shape)
    }

    /// Where a directional Maximize grows from in `space` on a
    /// screen of `shape`: the Space's own value, else the shape's.
    public func anchor(
        on shape: ScreenShape,
        in space: SpaceID?
    ) -> MaximizeAnchor {
        space.flatMap { anchorOverride[$0] } ?? anchor[shape]
    }

    /// Sets or clears (`nil`) `space`'s own `axis` share; an entry
    /// left with neither axis is dropped.
    public mutating func setShareOverride(
        _ share: Double?,
        for axis: MaximizeAxis,
        in space: SpaceID
    ) {
        var own = shareOverride[space] ?? MaximizeShareOverride()
        own[axis] = share
        shareOverride[space] = own.isEmpty ? nil : own
    }

    /// How many of `space`'s three Maximize rows it overrides, each
    /// counting one toward its override badge.
    public func overrideCount(for space: SpaceID) -> Int {
        let own = shareOverride[space]
        return (own?.height == nil ? 0 : 1)
            + (own?.width == nil ? 0 : 1)
            + (anchorOverride[space] == nil ? 0 : 1)
    }

    /// These settings as `space` uses them: its own values folded
    /// onto every shape through the reads above, the maps emptied —
    /// `TilingSettings.resolved(for:)`'s half.
    func resolved(for space: SpaceID) -> MaximizeSettings {
        var out = self
        for shape in ScreenShape.allCases {
            out.heightShare[shape] = share(
                for: .height,
                on: shape,
                in: space
            )
            out.widthShare[shape] = share(
                for: .width,
                on: shape,
                in: space
            )
            out.anchor[shape] = anchor(on: shape, in: space)
        }
        out.shareOverride = [:]
        out.anchorOverride = [:]
        return out
    }
}
