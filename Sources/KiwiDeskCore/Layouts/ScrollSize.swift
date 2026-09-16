import CoreGraphics
import Foundation

/// Scrolling slot size along the scroll axis (points, fraction,
/// or auto). `.auto` is a resolved default, never an inheritance
/// sentinel: a future per-space override layer must model
/// inheritance as `ScrollSize?` (`nil` = inherit) — do not
/// overload `.auto` for it.
public enum ScrollSize: Sendable, Equatable {
    /// Resolved orientation standard at layout time.
    case auto
    /// Absolute points along scroll axis.
    case points(CGFloat)
    /// Share (0...1) of the pitch — one slot plus one inner gap
    /// (#1382, `resolved`).
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

    /// `auto` + horizontal: a fraction, not points — a fixed pt
    /// count drifted across display sizes. Near-full on purpose:
    /// the 5% sliver of neighbour peeking in is what tells the
    /// user the space scrolls at all.
    public static let autoHorizontalFraction: Double = 0.95
    /// The vertical twin: a share of the pitch along the height.
    public static let autoVerticalFraction: Double = 0.95

    /// Resolves point extent along scroll axis clamped to available
    /// length. A fraction is a share of the PITCH — window plus
    /// one inner `gap` — so n slots of 1/n tile the axis exactly,
    /// gaps included (#1382).
    public func resolved(
        along: CGFloat,
        gap: CGFloat,
        horizontal: Bool
    ) -> CGFloat {
        let raw: CGFloat
        switch self {
        case .auto:
            raw = Self.pitched(
                horizontal
                    ? Self.autoHorizontalFraction
                    : Self.autoVerticalFraction,
                along: along,
                gap: gap
            )
        case .points(let points):
            raw = points
        case .fraction(let fraction):
            raw = Self.pitched(fraction, along: along, gap: gap)
        }
        return min(max(raw, 0), along)
    }

    /// `fraction` of the pitch, less the gap the pitch carries.
    private static func pitched(
        _ fraction: Double,
        along: CGFloat,
        gap: CGFloat
    ) -> CGFloat {
        CGFloat(fraction) * (along + gap) - gap
    }

    /// Starting magnitude for interactive resize calculations —
    /// the pitch share of the `along` it is handed (#1382), the
    /// number for points.
    public func editablePoints(
        along: CGFloat,
        gap: CGFloat,
        horizontal: Bool
    ) -> CGFloat {
        switch self {
        case .points(let points):
            return points
        case .auto, .fraction:
            return resolved(
                along: along,
                gap: gap,
                horizontal: horizontal
            )
        }
    }

    /// Formats fraction as percentage string for Lua/JSON
    /// encoding. 2-decimal precision, trimmed, so a half percent
    /// round-trips exactly — unlike a bare `Int(...)` cast.
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
