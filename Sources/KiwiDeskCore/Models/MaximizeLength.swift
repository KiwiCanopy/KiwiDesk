import CoreGraphics
import Foundation

/// How much of the other axis a directional Maximize takes (#3460):
/// a fraction of the screen's length, or a length in points that is
/// the same on every screen. Only
/// `TilingEngine.maximizedBounds(_:screen:slot:)` turns it into
/// points (state-and-layout.md ▸ A Maximize length resolves).
///
/// Stored as a bare number for a fraction, the spelling every
/// earlier build wrote, and `{"points": N}` for a length; anything
/// else throws (#3460, no `ConfigMigration`: no stored value changes
/// meaning).
public enum MaximizeLength: Equatable, Hashable, Sendable {
    case fraction(Double)
    case points(CGFloat)

    /// The fractions a share accepts; a value outside is clamped at
    /// the fill.
    public static let fractionRange: ClosedRange<Double> = 0.1...1

    /// The shortest length a binding, Lua or a stored cell may name
    /// (#3460).
    public static let minPoints: CGFloat = 100

    /// Maximize Height's width on the wide shapes (owner,
    /// 2026-11-18): the old fractions' width on the common 2560,
    /// 3840 and 5120 pt screens (½, ⅓, ¼).
    public static let wideColumn = MaximizeLength.points(1280)

    /// The fraction, nil for a length.
    public var fraction: Double? {
        if case .fraction(let value) = self { return value }
        return nil
    }

    /// The length in points, nil for a fraction.
    public var points: CGFloat? {
        if case .points(let value) = self { return value }
        return nil
    }

    /// Whether `other` is this value: a fraction within a rounding,
    /// so 0.6667 is ⅔ (#3062), a length to the half point.
    public func matches(_ other: MaximizeLength) -> Bool {
        switch (self, other) {
        case (.fraction(let a), .fraction(let b)): abs(a - b) < 0.005
        case (.points(let a), .points(let b)): abs(a - b) < 0.5
        default: false
        }
    }

    /// A binding's, Lua's or the CLI's argument (#3460): a number is
    /// a fraction in `fractionRange`, a string ending in `pt` or the
    /// `{points = N}` table `get_settings` returns a length of
    /// `minPoints` or more. Nothing guesses that a number above 1
    /// means points.
    public static func argument(_ value: JSONValue) -> MaximizeLength? {
        if let number = value.numberValue {
            return fractionRange.contains(number) ? .fraction(number) : nil
        }
        if case .object(let table) = value {
            guard table.count == 1, let points = table["points"]?.numberValue
            else { return nil }
            return length(points)
        }
        guard var text = value.stringValue?.lowercased(),
            text.hasSuffix("pt")
        else { return nil }
        text.removeLast(2)
        return Double(text.trimmingCharacters(in: .whitespaces))
            .flatMap(length)
    }

    private static func length(_ number: Double) -> MaximizeLength? {
        number.isFinite && CGFloat(number) >= minPoints
            ? .points(CGFloat(number)) : nil
    }

    /// The refusal every setter of a share answers a bad argument
    /// with (#3460).
    public static let expected =
        "expected a share from \(wire(fractionRange.lowerBound)) to "
        + "\(wire(fractionRange.upperBound)) or a length like \"800pt\""

    /// A bound as a call spells it: `1`, never `1.0`.
    private static func wire(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : "\(value)"
    }
}

extension MaximizeLength: Codable {
    private enum Keys: String, CodingKey {
        case points
    }

    /// Any key, so an object carrying one beside `points` throws.
    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
            let number = try? single.decode(Double.self)
        {
            self = .fraction(number)
            return
        }
        let container = try decoder.container(keyedBy: Keys.self)
        let every = try decoder.container(keyedBy: AnyKey.self).allKeys
        guard every.map(\.stringValue) == [Keys.points.rawValue] else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "expected a number or {\"points\": N}"
                )
            )
        }
        let points = try container.decode(Double.self, forKey: .points)
        guard points.isFinite, CGFloat(points) >= Self.minPoints else {
            throw DecodingError.dataCorruptedError(
                forKey: .points,
                in: container,
                debugDescription: "a length is \(Self.minPoints) pt or more"
            )
        }
        self = .points(CGFloat(points))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .fraction(let value):
            var single = encoder.singleValueContainer()
            try single.encode(value)
        case .points(let value):
            var container = encoder.container(keyedBy: Keys.self)
            try container.encode(Double(value), forKey: .points)
        }
    }
}
