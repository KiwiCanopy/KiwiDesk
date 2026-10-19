import CoreGraphics

/// A layout's minimum window size in points, per axis (#2237).
/// A floor, never a target: a layout tiles no window smaller than
/// this and piles or scrolls instead. Each consumer reads the axis
/// its geometry divides — `along(horizontal:)` names it.
public struct MinSize: Sendable, Equatable, Hashable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    /// The same floor on both axes.
    public static func square(_ side: CGFloat) -> MinSize {
        MinSize(width: side, height: side)
    }

    /// The floor along an axis: the width where `horizontal`, the
    /// height otherwise.
    public func along(horizontal: Bool) -> CGFloat {
        horizontal ? width : height
    }

    /// The floor on a resize axis named the way the resize paths
    /// name it (`"x"` is the width).
    public func on(axis: String) -> CGFloat {
        axis == "x" ? width : height
    }

    /// The larger of the two axes — the side a square pile needs
    /// to keep both floors.
    public var larger: CGFloat { max(width, height) }
}

extension MinSize: ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral
{
    /// A literal is the same floor on both axes, the shape every
    /// fixture states.
    public init(integerLiteral value: Int) {
        self = .square(CGFloat(value))
    }

    public init(floatLiteral value: Double) {
        self = .square(CGFloat(value))
    }
}

extension MinSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width
        case height
    }
}
