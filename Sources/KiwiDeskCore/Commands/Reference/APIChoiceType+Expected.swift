import Foundation

/// The one derivation behind "here is what I do accept" (#1033).
///
/// A decoder that rejects a value owes the caller the list of
/// values it would have taken, and that list is the enum's, not
/// a sentence beside it. Two of these had already gone stale
/// identically — both bars told the user to send
/// `ring|edge_mark|gap` long after the case was renamed
/// `outline` — and the reason is that a hand-typed list is
/// right on the day it is written and silent every day after.
///
/// `quit.set_layout` had derived its message this way since it
/// shipped; this is that call site's shape, made shareable so
/// every enum-valued setter can take it.
extension APIChoiceType {
    /// Every case's wire spelling, `a|b|c`, in declaration
    /// order — the same order `list_commands` prints.
    public static var expectedList: String {
        allCases.map(\.rawValue).joined(separator: "|")
    }
}

extension CommandResponse {
    /// A rejection naming every value `type` accepts.
    ///
    /// Takes the TYPE, never a message, for the same reason
    /// `APIArgument.choice` does: a call site that cannot spell
    /// the list cannot spell it wrongly.
    public static func expected<T: APIChoiceType>(
        _ type: T.Type
    ) -> CommandResponse {
        .fail("expected \(T.expectedList)")
    }
}
