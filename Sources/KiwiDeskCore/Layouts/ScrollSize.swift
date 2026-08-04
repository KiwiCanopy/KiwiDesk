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
/// `.auto` is a *resolved default*, not an inheritance sentinel: it
/// means "the orientation standard", never "inherit some other
/// value". A future per-space override layer must model inheritance
/// as `ScrollSize?` (`nil` = inherit), mirroring `LayoutAppBar`'s
/// optional fields — do not overload `.auto` for that.
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

    // MARK: - Validity policy (single source of truth)

    /// Smallest usable slot in points. Every ingest path (Lua,
    /// resize, decode) funnels through the clamping factories so
    /// this floor is defined exactly once.
    public static let minPoints: CGFloat = 100
    /// Fraction bounds — at least a sliver, at most the whole axis.
    public static let minFraction: Double = 0.05
    public static let maxFraction: Double = 1

    /// `.points` clamped to the valid floor.
    public static func points(clamping value: CGFloat) -> ScrollSize {
        .points(max(value, minPoints))
    }

    /// `.fraction` clamped to the valid range.
    public static func fraction(
        clamping value: Double
    ) -> ScrollSize {
        .fraction(min(max(value, minFraction), maxFraction))
    }

    // MARK: - Auto standards (scrolling policy)

    /// `auto` + horizontal → this fraction of the *available*
    /// width. A fraction keeps the column's share of the screen
    /// identical across displays and scaled-resolution settings,
    /// where a fixed pt count drifted (the same 1100 pt column was
    /// ~73% of a 14" MBP but ~64% of a 16"). On an ultrawide the
    /// resolved column is huge — an accepted trade; set an
    /// explicit pt/% slot size there.
    ///
    /// The shipped standard is a *near*-full slot: the sliver the
    /// remaining 5% leaves is what tells the user the space
    /// scrolls at all, so it is the neighbour peeking in — not
    /// spare room — that earns the fraction. A full-axis slot is
    /// still settable (`maxFraction`) and still renders; it just
    /// looks like a monocle until the focus moves.
    public static let autoHorizontalFraction: Double = 0.95
    /// `auto` + vertical → this fraction of the *available*
    /// height, the same standard as horizontal so neither axis
    /// surprises after an orientation flip. Height is bounded, so
    /// a fraction adapts across laptop and desktop where a pt
    /// count would not.
    public static let autoVerticalFraction: Double = 0.95

    // MARK: - Resolution

    /// The resolved point extent along the scroll axis, clamped to
    /// the available `along` length. `auto` resolves to the
    /// per-orientation standard fraction of `along`.
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

    /// The starting magnitude for *editing* (resize): a `.points`
    /// value is returned as stored, unclamped by `along`, so an
    /// explicit oversized slot is never silently rewritten. Only
    /// `.auto`/`.fraction` need `along` to seed a pt value.
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

    /// The `"NN%"` spelling shared by JSON encode and the Lua
    /// writer. Formatted to 2-decimal precision and trimmed, so a
    /// whole or half percent round-trips exactly (no integer
    /// truncation), unlike a bare `Int(...)` cast.
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
