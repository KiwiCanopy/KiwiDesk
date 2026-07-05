import CoreGraphics
import Foundation

/// The size of a scrolling slot *along the scroll axis* (column
/// width when horizontal, row height when vertical). The cross-axis
/// always fills, so this one value is the only meaningful size.
///
/// Ghostty-style single-value-with-unit: a point count, a fraction
/// of the along-axis length, or `auto` (resolve to an
/// orientation-aware standard at layout time). There is exactly one
/// size in one unit, so there is no precedence to arbitrate.
///
/// Codable shape (one JSON value, mirroring the Lua setter):
/// `0` → `auto`, a positive number → points, a `"NN%"` string →
/// fraction.
public enum ScrollSize: Sendable, Equatable {
    /// Resolve to a per-orientation standard at layout time.
    case auto
    /// Absolute points along the scroll axis.
    case points(CGFloat)
    /// Fraction (0...1) of the along-axis length.
    case fraction(Double)

    /// Standard column width used when `auto` and horizontal — a
    /// `%` default would look bad on very wide screens, so the
    /// auto fallback is a fixed pt, orientation-aware.
    public static let autoHorizontal: CGFloat = 1100
    /// Standard row height used when `auto` and vertical.
    public static let autoVertical: CGFloat = 800

    /// The resolved point extent along the scroll axis, clamped to
    /// the available `along` length. `auto` resolves to the
    /// per-orientation standard.
    public func resolved(
        along: CGFloat,
        horizontal: Bool
    ) -> CGFloat {
        let raw: CGFloat
        switch self {
        case .auto:
            raw = horizontal ? Self.autoHorizontal : Self.autoVertical
        case .points(let points):
            raw = points
        case .fraction(let fraction):
            raw = CGFloat(fraction) * along
        }
        return min(max(raw, 0), along)
    }
}

extension ScrollSize: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            // "NN%" → fraction; anything else → auto.
            if string.hasSuffix("%"),
                let percent = Double(string.dropLast())
            {
                self = .fraction(percent / 100)
            } else {
                self = .auto
            }
        } else if let number = try? container.decode(Double.self) {
            self = number <= 0 ? .auto : .points(CGFloat(number))
        } else {
            self = .auto
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto:
            try container.encode(0)
        case .points(let points):
            try container.encode(Double(points))
        case .fraction(let fraction):
            let percent = Int((fraction * 100).rounded())
            try container.encode("\(percent)%")
        }
    }
}
