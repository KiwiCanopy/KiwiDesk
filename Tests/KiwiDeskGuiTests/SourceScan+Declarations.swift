import Foundation

/// Two walkers that ask what a piece of source SAYS rather than
/// only whether a needle occurs in it: the body a declaration
/// opens, and the arguments a call was handed.
///
/// In this family (`.claude/rules/tests.md` ▸ source-scanning
/// primitives) rather than private to a suite, at the second
/// consumer — `UpdatePromptFocusTests` and
/// `UpdatePromptWiringTests`, which #1011's guard split into.
/// The drift risk is the family's own: `declarationBody` is what
/// scopes a needle to ONE class, and a copy that lost the scoping
/// would go green on a decoy declaration elsewhere in the file —
/// which is not hypothetical, it is the escape a `guard-prover`
/// round found in the unscoped first cut.
extension SourceScan {
    /// The balanced `{ … }` that follows the first `declaration`
    /// in `text`, or nil when it is absent or unbalanced.
    ///
    /// Composable on purpose: handed a class body it searches
    /// inside that body, which is how a needle is pinned to the
    /// declaration that is live rather than to the first one
    /// spelled in the file.
    static func declarationBody(
        after declaration: String,
        in text: String
    ) -> String? {
        guard let declared = text.range(of: declaration)
        else { return nil }
        let characters = Array(text)
        let offset = text.distance(
            from: text.startIndex,
            to: declared.lowerBound
        )
        guard
            var cursor = characters[offset...].firstIndex(of: "{")
        else { return nil }
        return balanced(
            characters,
            from: &cursor,
            open: "{",
            close: "}"
        )
    }

    /// The balanced `( … )` of the first `call` in `text` — the
    /// argument list, so a needle can ask what a call was HANDED
    /// rather than only that it exists.
    static func callArguments(
        of call: String,
        in text: String
    ) -> String? {
        guard let made = text.range(of: call) else { return nil }
        var cursor =
            text.distance(
                from: text.startIndex,
                to: made.upperBound
            ) - 1
        return balanced(
            Array(text),
            from: &cursor,
            open: "(",
            close: ")"
        )
    }
}
