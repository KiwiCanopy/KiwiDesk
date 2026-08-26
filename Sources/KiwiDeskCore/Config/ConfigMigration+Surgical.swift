import Foundation

/// The envelope every rewriting step shares: **the parse
/// decides, a textual edit applies, and an edit that is ever
/// wrong is simply not used.**
///
/// Extracted because it had reached three copies — the
/// bar-content rewrite, the format stamp and the scroll-duration
/// key rename — each re-prosing the same argument beside a walk
/// of its own (architect review, 2026-08-27). The WALKS stay
/// duplicated and should: a value map with no collision case and
/// a key rename with a both-spellings rule are genuinely
/// different, and AGENTS.md §2.4 prefers a small readable
/// duplication to a hierarchy. What must not be duplicated is
/// this envelope, because the load-bearing part of it is a
/// safety net — and a fourth step that copies the shape and
/// drops the compare is green on the day it lands.
///
/// Why a textual edit at all: re-serializing the parsed tree
/// re-encodes every `Double` in the file. `0.4` became
/// `0.40000000000000002` and `0.6` became `0.59999999999999998`,
/// in five places, for a ONE-value migration (measured,
/// 2026-08-20). The decoded values are identical, so nothing
/// breaks; what breaks is the promise. This rewrites the user's
/// file without being asked, so it may touch only what it came
/// for — a config kept in a dotfiles repo shows every unasked
/// byte as a diff.
///
/// Correctness does not rest on the edit: its result is
/// re-parsed and compared against the tree the walk produced,
/// and anything but an exact match falls back to serializing
/// that tree.
extension ConfigMigration {
    /// `data` rewritten by `rewriting`, applied surgically by
    /// `editing` where that is provably equivalent, or nil when
    /// the gate refuses, the bytes do not parse, or the walk
    /// changed nothing.
    ///
    /// Nil rather than the unchanged bytes, deliberately: a
    /// caller writes back exactly when this returns non-nil, so
    /// a config that needs nothing is never rewritten and its
    /// mtime never moves.
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

    /// One serializer for both sides of the comparison, so the
    /// check is about VALUES and never about how either side
    /// happened to spell a float.
    static func canonical(_ node: Any) -> Data? {
        try? JSONSerialization.data(
            withJSONObject: node,
            options: [.sortedKeys]
        )
    }
}
