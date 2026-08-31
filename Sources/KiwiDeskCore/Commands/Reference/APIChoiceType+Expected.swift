import Foundation

/// Dynamic choice type enumeration string derivation for commands (#1033).
extension APIChoiceType {
    /// Pipe-delimited wire spellings in declaration order.
    public static var expectedList: String {
        allCases.map(\.rawValue).joined(separator: "|")
    }
}

extension CommandResponse {
    /// Rejection naming accepted choice values derived from type (#1033).
    public static func expected<T: APIChoiceType>(
        _ type: T.Type
    ) -> CommandResponse {
        .fail("expected \(T.expectedList)")
    }
}
