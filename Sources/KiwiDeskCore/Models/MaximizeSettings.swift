import Foundation

/// The `maximize.*` settings (#3062): for each shape of screen, the
/// share of the other axis each directional Maximize takes and
/// where it grows from. A press reads the row of the screen the
/// window is on; a binding's own arguments win. Every shape is
/// stored, with no value behind them (amendment, owner 2026-11-08).
public struct MaximizeSettings: Sendable, Equatable {
    /// The width share of a Maximize Height
    /// (`maximize.share.height.<shape>`).
    public var heightShare = PerScreenShape(Self.defaultHeightShare)
    /// The height share of a Maximize Width
    /// (`maximize.share.width.<shape>`).
    public var widthShare = PerScreenShape(Self.defaultWidthShare)
    /// Where a directional Maximize grows from
    /// (`maximize.anchor.<shape>`).
    public var anchor = PerScreenShape(Self.defaultAnchor)
    /// Whether a new Maximize moves to the tiled window focus lands
    /// on instead of ending (`maximize.follow_focus`, #3063); one
    /// value for every shape.
    public var followFocus = false
    /// Each Space's own shares, outranking its screen shape's row
    /// (`maximize.share_override`, #3090).
    public var shareOverride: [SpaceID: MaximizeShareOverride] = [:]
    /// Each Space's own anchor (`maximize.anchor_override`, #3090).
    public var anchorOverride: [SpaceID: MaximizeAnchor] = [:]

    public init() {}

    /// The share a press of `axis` takes on a screen of `shape`.
    public func share(
        for axis: MaximizeAxis,
        on shape: ScreenShape
    ) -> Double {
        switch axis {
        case .height: heightShare[shape]
        case .width: widthShare[shape]
        }
    }

    /// Sets `axis`'s share for `shape`, or for every shape when nil.
    public mutating func setShare(
        _ share: Double,
        for axis: MaximizeAxis,
        on shape: ScreenShape?
    ) {
        switch axis {
        case .height: heightShare.set(share, on: shape)
        case .width: widthShare.set(share, on: shape)
        }
    }

    /// The width share each shape starts with (owner, 2026-11-08):
    /// a narrow screen gives a wider column, a wide one a narrower.
    public static func defaultHeightShare(_ shape: ScreenShape) -> Double {
        switch shape {
        case .laptop, .portrait: 3 / 4
        case .widescreen: 1 / 2
        case .ultrawide: 1 / 3
        case .superUltrawide: 1 / 4
        }
    }

    /// The height share each shape starts with (owner, 2026-11-08).
    public static func defaultWidthShare(_ shape: ScreenShape) -> Double {
        shape == .laptop ? 2 / 3 : 1 / 2
    }

    /// Where each shape grows from by default (owner, 2026-11-08).
    public static func defaultAnchor(
        _ shape: ScreenShape
    ) -> MaximizeAnchor {
        switch shape {
        case .ultrawide, .superUltrawide: .inPlace
        case .laptop, .widescreen, .portrait: .center
        }
    }
}

extension MaximizeSettings: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case share
        case anchor
        case followFocus = "follow_focus"
        case shareOverride = "share_override"
        case anchorOverride = "anchor_override"
    }

    enum ShareKeys: String, CodingKey, CaseIterable {
        case height
        case width
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        followFocus =
            try container.decodeIfPresent(Bool.self, forKey: .followFocus)
            ?? defaults.followFocus
        shareOverride =
            try container.decodeIfPresent(
                [SpaceID: MaximizeShareOverride].self,
                forKey: .shareOverride
            ) ?? [:]
        anchorOverride =
            try container.decodeIfPresent(
                [SpaceID: MaximizeAnchor].self,
                forKey: .anchorOverride
            ) ?? [:]
        if container.contains(.anchor) {
            anchor = try .decode(
                container.nestedContainer(
                    keyedBy: ScreenShape.self,
                    forKey: .anchor
                ),
                defaults: defaults.anchor
            )
        }
        guard container.contains(.share) else { return }
        let share = try container.nestedContainer(
            keyedBy: ShareKeys.self,
            forKey: .share
        )
        if share.contains(.height) {
            heightShare = try .decode(
                share.nestedContainer(
                    keyedBy: ScreenShape.self,
                    forKey: .height
                ),
                defaults: defaults.heightShare
            )
        }
        if share.contains(.width) {
            widthShare = try .decode(
                share.nestedContainer(
                    keyedBy: ScreenShape.self,
                    forKey: .width
                ),
                defaults: defaults.widthShare
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var share = container.nestedContainer(
            keyedBy: ShareKeys.self,
            forKey: .share
        )
        var height = share.nestedContainer(
            keyedBy: ScreenShape.self,
            forKey: .height
        )
        try heightShare.encode(into: &height)
        var width = share.nestedContainer(
            keyedBy: ScreenShape.self,
            forKey: .width
        )
        try widthShare.encode(into: &width)
        var anchors = container.nestedContainer(
            keyedBy: ScreenShape.self,
            forKey: .anchor
        )
        try anchor.encode(into: &anchors)
        try container.encode(followFocus, forKey: .followFocus)
        try container.encode(shareOverride, forKey: .shareOverride)
        try container.encode(anchorOverride, forKey: .anchorOverride)
    }
}
