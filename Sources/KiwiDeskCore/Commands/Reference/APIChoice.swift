import Foundation

/// The legal values of an enum-typed argument, read off the
/// Swift type that decodes it (#1033).
///
/// **This type has one file and one initializer, and both are
/// load-bearing.** A `guard-prover` round defeated an earlier
/// arrangement by adding a second initializer in an extension —
/// which compiled, read harmlessly, and let a record advertise
/// `diag` as an `AppBarEdge`, a value the decoder rejects. That
/// is the exact drift #1033 exists to remove, arriving inside
/// its own fix, with every test green.
///
/// Two things close it, and neither is a scan:
///
/// - The values live in a `private` stored property, so an
///   initializer written in **any other file** cannot exist —
///   it could not set it, and would not compile.
/// - This file therefore has to hold every initializer there
///   is, which makes "how many initializers does `APIChoice`
///   have" a question a scan of one small file can answer
///   totally. `APIChoiceDerivationTests` asks it here, of the
///   whole file, rather than of a slice between two markers.
public struct APIChoice: Sendable, Equatable {
    /// Private on purpose — see the type's own doc. This is
    /// what makes a second initializer a compile error rather
    /// than a review question.
    private let derived: Derived

    private struct Derived: Sendable, Equatable {
        let type: String
        let values: [String]
    }

    /// The Swift type the values came from, module prefix
    /// stripped (`ScrollingParams.Anchor`). Printed in the
    /// terminal rendering so a reader can find the decoder;
    /// deliberately not a JSON field, since a Swift symbol must
    /// not become part of the CLI's output contract.
    public var type: String { derived.type }

    /// Every case's wire spelling, in declaration order.
    public var values: [String] { derived.values }

    /// **The one initializer.** It takes a metatype and reads
    /// the cases; there is deliberately no way to hand it a
    /// list, because a hand-written list is the drift #1033 was
    /// filed about.
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

/// A decoder enum whose cases are an argument's legal values.
///
/// Conformances are declared once, in `APIChoiceTypes.swift`,
/// which is the census of every enum the API surface exposes.
public protocol APIChoiceType: CaseIterable, RawRepresentable
where RawValue == String {}
