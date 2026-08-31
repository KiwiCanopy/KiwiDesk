import Foundation

/// Surgical textual rewriting: the parse decides, a textual
/// edit applies, and an edit that is ever wrong is simply not
/// used — the result is re-parsed and compared against the tree
/// the walk produced. The envelope must not be duplicated
/// (AGENTS.md §2.4): a step that copies the shape and drops the
/// compare is green the day it lands. Why textual at all:
/// re-serializing re-encodes every Double (`0.4` became
/// `0.40000000000000002`, five places, for a one-value migration
/// — measured 2026-08-20), and a rewrite of the user's file may
/// touch only what it came for.
extension ConfigMigration {
    /// Rewrites `data` using surgical text edits when verified by re-parsing,
    /// or falls back to serialized JSON tree; returns nil if unchanged.
    static func surgicallyApplying(
        _ data: Data,
        gate: (Data) -> Bool = { _ in true },
        rewriting: (Any) -> (Any, Bool),
        editing: (String) -> Data?
    ) -> Data? {
        // Cheap gate first: a config that never set the value in
        // question — the common case, since every field is
        // sparse — costs one substring scan rather than a parse.
        guard gate(data) else { return nil }
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
        else { return nil }
        let (expected, changed) = rewriting(root)
        guard changed else { return nil }
        if let text = String(data: data, encoding: .utf8),
            let edited = editing(text),
            let reparsed = try? JSONSerialization.jsonObject(
                with: edited
            ),
            canonical(reparsed) == canonical(expected)
        {
            return edited
        }
        return try? JSONSerialization.data(
            withJSONObject: expected,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Serializes JSON node to canonical formatted data for value comparison.
    static func canonical(_ node: Any) -> Data? {
        try? JSONSerialization.data(
            withJSONObject: node,
            options: [.sortedKeys]
        )
    }
}
