import Foundation

/// Encapsulates legal values of enum-typed arguments derived from Swift types
/// (`APIChoiceDerivationTests`, #1033).
public struct APIChoice: Sendable, Equatable {
    /// Private backing container preventing external initializers (#1033).
    private let derived: Derived

    private struct Derived: Sendable, Equatable {
        let type: String
        let values: [String]
    }

    /// Swift type name without module prefix (`ScrollingParams.Anchor`).
    public var type: String { derived.type }

    /// Case wire spellings in declaration order.
    public var values: [String] { derived.values }

    /// Sole initializer reading cases directly from metatype (#1033).
    public init<T: APIChoiceType>(_ type: T.Type) {
        let qualified = String(reflecting: type)
        let module = "KiwiDeskCore."
        derived = Derived(
            type: qualified.hasPrefix(module)
                ? String(qualified.dropFirst(module.count))
                : qualified,
            values: T.allCases.map(\.rawValue)
        )
    }
}

/// Decoder enum protocol for legal argument values (`APIChoiceTypes.swift`).
public protocol APIChoiceType: CaseIterable, RawRepresentable
where RawValue == String {}
