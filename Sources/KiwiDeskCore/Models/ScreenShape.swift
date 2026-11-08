import Foundation

/// A screen's shape as a setting names it (#3062): one `ScreenClass`
/// each, spelled with the starter's nouns, in the order Settings
/// lists them. The raw value is the Lua and JSON spelling. Apart
/// from `ScreenClass` because that type's case order IS its
/// classification order (`ScreenClassTests`), which is not the
/// order a table of shapes reads in.
public enum ScreenShape: String, CaseIterable, Codable, Sendable,
    CodingKey
{
    case laptop
    case widescreen
    case ultrawide
    case superUltrawide = "super_ultrawide"
    case portrait

    /// The shape of a screen of `screenClass`.
    public init(_ screenClass: ScreenClass) {
        switch screenClass {
        case .laptop: self = .laptop
        case .desktop: self = .widescreen
        case .ultrawide: self = .ultrawide
        case .superUltrawide: self = .superUltrawide
        case .pivoted: self = .portrait
        }
    }

    /// The shape of `display`, by its full frame.
    public static func of(_ display: Display) -> ScreenShape {
        ScreenShape(ScreenClass.of(display))
    }

    /// The class this shape names.
    public var screenClass: ScreenClass {
        switch self {
        case .laptop: .laptop
        case .widescreen: .desktop
        case .ultrawide: .ultrawide
        case .superUltrawide: .superUltrawide
        case .portrait: .pivoted
        }
    }
}

/// One value for each `ScreenShape`, every one always stored (#3062).
public struct PerScreenShape<Value>: Sendable, Equatable
where Value: Sendable & Equatable & Codable {
    public var laptop: Value
    public var widescreen: Value
    public var ultrawide: Value
    public var superUltrawide: Value
    public var portrait: Value

    /// Each shape's value from `value`.
    public init(_ value: (ScreenShape) -> Value) {
        laptop = value(.laptop)
        widescreen = value(.widescreen)
        ultrawide = value(.ultrawide)
        superUltrawide = value(.superUltrawide)
        portrait = value(.portrait)
    }

    public subscript(shape: ScreenShape) -> Value {
        get {
            switch shape {
            case .laptop: laptop
            case .widescreen: widescreen
            case .ultrawide: ultrawide
            case .superUltrawide: superUltrawide
            case .portrait: portrait
            }
        }
        set {
            switch shape {
            case .laptop: laptop = newValue
            case .widescreen: widescreen = newValue
            case .ultrawide: ultrawide = newValue
            case .superUltrawide: superUltrawide = newValue
            case .portrait: portrait = newValue
            }
        }
    }

    /// Writes `value` for `shape`, or for every shape when nil.
    public mutating func set(_ value: Value, on shape: ScreenShape?) {
        guard let shape else {
            self = Self { _ in value }
            return
        }
        self[shape] = value
    }

    /// Decodes each shape present in `decoder`'s keyed object,
    /// keeping `defaults`' value for one it omits.
    static func decode(
        _ container: KeyedDecodingContainer<ScreenShape>,
        defaults: Self
    ) throws -> Self {
        var values = defaults
        for shape in ScreenShape.allCases {
            if let value = try container.decodeIfPresent(
                Value.self,
                forKey: shape
            ) {
                values[shape] = value
            }
        }
        return values
    }

    /// Encodes every shape.
    func encode(
        into container: inout KeyedEncodingContainer<ScreenShape>
    ) throws {
        for shape in ScreenShape.allCases {
            try container.encode(self[shape], forKey: shape)
        }
    }
}

/// One value per shape is ONE setting, a column of the Maximize
/// table, so reflection reads it as a collection rather than five
/// fields: the GUI's census holds a row per column
/// (`SettingKeyModelParityTests`).
extension PerScreenShape: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(
            self,
            unlabeledChildren: ScreenShape.allCases.map { self[$0] },
            displayStyle: .collection
        )
    }
}
