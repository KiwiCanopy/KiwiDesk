import CoreGraphics
import Foundation

/// Scrolling slot size along scroll axis (points, fraction, or auto).
public enum ScrollSize: Sendable, Equatable {
    /// Resolved orientation standard at layout time.
    case auto
    /// Absolute points along scroll axis.
    case points(CGFloat)
    /// Fraction (0...1) of along-axis length.
    case fraction(Double)

    /// Minimum usable slot size in points.
    public static let minPoints: CGFloat = 100
    /// Fraction bounds (0.05...1.0).
    public static let minFraction: Double = 0.05
    public static let maxFraction: Double = 1

    /// Points clamped to minimum threshold.
    public static func points(clamping value: CGFloat) -> ScrollSize {
        .points(max(value, minPoints))
    }

    /// Fraction clamped to valid range.
    public static func fraction(
        clamping value: Double
    ) -> ScrollSize {
        .fraction(min(max(value, minFraction), maxFraction))
    }

    /// Standard fraction of available width for auto horizontal scrolling.
    public static let autoHorizontalFraction: Double = 0.95
    /// Standard fraction of available height for automatic vertical scrolling.
    public static let autoVerticalFraction: Double = 0.95

    /// Resolves point extent along scroll axis clamped to available length.
    public func resolved(
        along: CGFloat,
        horizontal: Bool
    ) -> CGFloat {
        let raw: CGFloat
        switch self {
        case .auto:
            raw =
                along
                * CGFloat(
                    horizontal
                        ? Self.autoHorizontalFraction
                        : Self.autoVerticalFraction
                )
        case .points(let points):
            raw = points
        case .fraction(let fraction):
            raw = CGFloat(fraction) * along
        }
        return min(max(raw, 0), along)
    }

    /// Starting magnitude for interactive resize calculations.
    public func editablePoints(
        along: CGFloat,
        horizontal: Bool
    ) -> CGFloat {
        switch self {
        case .points(let points):
            return points
        case .auto, .fraction:
            return resolved(along: along, horizontal: horizontal)
        }
    }

    /// Formats fraction as percentage string for Lua/JSON encoding.
    public static func percentString(_ fraction: Double) -> String {
        var text = String(format: "%.2f", fraction * 100)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text + "%"
    }
}

extension ScrollSize: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            // "NN%" → fraction (clamped); anything else → auto.
            if string.hasSuffix("%"),
                let percent = Double(string.dropLast())
            {
                self = .fraction(clamping: percent / 100)
            } else {
                self = .auto
            }
        } else if let number = try? container.decode(Double.self) {
            self =
                number <= 0
                ? .auto : .points(clamping: CGFloat(number))
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
            try container.encode(Self.percentString(fraction))
        }
    }
}
