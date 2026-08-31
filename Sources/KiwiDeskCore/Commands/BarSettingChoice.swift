import Foundation

/// Decodes enum bar setting and formats validation error from cases (#1033).
enum BarSettingChoice {
    /// Decodes value or returns failure listing expected enum cases.
    static func value<T: APIChoiceType>(
        _ args: [JSONValue],
        _ type: T.Type
    ) -> Result<T, AppBarSettingError> {
        guard let raw = args.first?.stringValue,
            let value = T(rawValue: raw)
        else {
            let expected = T.allCases
                .map(\.rawValue)
                .joined(separator: "|")
            return .failure("expected \(expected)")
        }
        return .success(value)
    }
}
