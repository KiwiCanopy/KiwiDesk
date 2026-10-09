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

    /// `set_edge`'s arguments (#1948): the edge, then an optional
    /// screen — a fingerprint by now, since `KiwiCore` resolves a
    /// number or a name ahead of the parse
    /// (`screenResolvedEdgeArgs`).
    static func edge(
        _ args: [JSONValue]
    ) -> Result<(edge: AppBarEdge, screen: String?), AppBarSettingError> {
        value(args, AppBarEdge.self).flatMap { edge in
            guard args.count > 1 else { return .success((edge, nil)) }
            guard let screen = args[1].stringValue, !screen.isEmpty
            else { return .failure("expected a screen") }
            return .success((edge, screen))
        }
    }
}
