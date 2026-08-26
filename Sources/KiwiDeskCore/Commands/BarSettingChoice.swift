import Foundation

/// Decodes an enum-valued bar setting, and builds its "expected"
/// message from the enum's own cases (#1033).
///
/// Shared by `AppBarCommandSetting` and `SpaceBarCommandSetting`,
/// which each carried a copy taking that message as a hand-typed
/// STRING — and both had gone stale the same way:
/// `active_indicator` told the user to send `ring|edge_mark|gap`
/// long after the case was renamed `outline`, so the error named
/// a value its own decoder would reject. Two copies of a list
/// nothing derives is how that happens twice.
///
/// Reading `allCases` here is the same derivation `APIChoice`
/// makes for `list_commands`: the values a caller is told about
/// and the values a caller may send are one list, in one place.
enum BarSettingChoice {
    /// The decoded value, or a failure naming every legal
    /// spelling in the order the enum declares them.
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
