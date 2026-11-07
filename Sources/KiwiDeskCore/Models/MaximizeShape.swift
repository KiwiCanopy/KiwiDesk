import Foundation

/// The axis a directional Maximize fills (#3062): `height` fills the
/// screen top to bottom at a share of its width, `width` the
/// reverse.
public enum MaximizeAxis: String, Codable, Sendable, CaseIterable {
    case height
    case width
}

/// Where a directional Maximize sits on its other axis (#3062):
/// centred on the screen, or centred on the window's own slot and
/// moved back inside the screen.
public enum MaximizeAnchor: String, Codable, Sendable, CaseIterable {
    case center
    case inPlace = "in_place"
}

/// What one Maximize fills: the whole screen (`axis` nil), or one
/// axis at `share` of the other, anchored by `anchor` (#3062).
public struct MaximizeShape: Equatable, Sendable, Codable {
    public var axis: MaximizeAxis?
    public var share: Double
    public var anchor: MaximizeAnchor

    public init(
        axis: MaximizeAxis?,
        share: Double = 1,
        anchor: MaximizeAnchor = .center
    ) {
        self.axis = axis
        self.share = axis == nil ? 1 : share
        self.anchor = axis == nil ? .center : anchor
    }

    /// Today's Maximize (#2448): the whole screen.
    public static let full = MaximizeShape(axis: nil)

    /// The shares a fill accepts; a value outside is clamped here.
    public static let shareRange: ClosedRange<Double> = 0.1...1
}

/// The `maximize.*` settings (#3062): each axis's share and where a
/// directional Maximize grows from. A binding's own arguments win.
public struct MaximizeSettings: Sendable, Equatable {
    /// The width share of a Maximize Height (`maximize.share.height`).
    public var heightShare = 0.5
    /// The height share of a Maximize Width (`maximize.share.width`).
    public var widthShare = 0.5
    /// Where a directional Maximize grows from (`maximize.anchor`).
    public var anchor: MaximizeAnchor = .center

    public init() {}

    /// The stored share for `axis`.
    public func share(for axis: MaximizeAxis) -> Double {
        switch axis {
        case .height: heightShare
        case .width: widthShare
        }
    }

    /// Sets the stored share for `axis`.
    public mutating func setShare(_ share: Double, for axis: MaximizeAxis) {
        switch axis {
        case .height: heightShare = share
        case .width: widthShare = share
        }
    }
}

extension MaximizeSettings: Codable {
    enum CodingKeys: String, CodingKey, CaseIterable {
        case share
        case anchor
    }

    enum ShareKeys: String, CodingKey, CaseIterable {
        case height
        case width
    }

    public init(from decoder: Decoder) throws {
        let defaults = Self()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anchor =
            try container.decodeIfPresent(
                MaximizeAnchor.self,
                forKey: .anchor
            ) ?? defaults.anchor
        guard container.contains(.share) else { return }
        let share = try container.nestedContainer(
            keyedBy: ShareKeys.self,
            forKey: .share
        )
        heightShare =
            try share.decodeIfPresent(Double.self, forKey: .height)
            ?? defaults.heightShare
        widthShare =
            try share.decodeIfPresent(Double.self, forKey: .width)
            ?? defaults.widthShare
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var share = container.nestedContainer(
            keyedBy: ShareKeys.self,
            forKey: .share
        )
        try share.encode(heightShare, forKey: .height)
        try share.encode(widthShare, forKey: .width)
        try container.encode(anchor, forKey: .anchor)
    }
}
