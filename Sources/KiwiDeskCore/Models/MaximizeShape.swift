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

/// A Space's Maximize (#2448): the window filling its screen (a
/// traveler's too, #3035) and what it fills (#3062), one value so an
/// ender's `maximized = nil` clears both. Session-only; read through
/// `StateCoordinator.maximizedWindow(of:)` and `maximizedShape(of:)`.
public struct Maximize: Equatable, Sendable {
    public var window: WindowID
    public var shape: MaximizeShape

    public init(window: WindowID, shape: MaximizeShape = .full) {
        self.window = window
        self.shape = shape
    }
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
        // A whole share fills the screen: it IS a full Maximize, so
        // every reader of "fills its screen" asks `axis` alone.
        let full = axis == nil || share >= 1
        self.axis = full ? nil : axis
        self.share = full ? 1 : share
        self.anchor = full ? .center : anchor
    }

    /// Whether `other` is this shape, its share within a rounding
    /// of this one's, so a share typed as 0.6667 is ⅔ (#3062).
    public func matches(_ other: MaximizeShape) -> Bool {
        axis == other.axis && anchor == other.anchor
            && abs(share - other.share) < 0.005
    }

    /// Today's Maximize (#2448): the whole screen.
    public static let full = MaximizeShape(axis: nil)

    /// The shares a fill accepts; a value outside is clamped here.
    public static let shareRange: ClosedRange<Double> = 0.1...1
}
