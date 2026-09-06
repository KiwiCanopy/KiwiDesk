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

extension SourceScan {
    /// Every member `text` declares, paired with the balanced
    /// body it opens — so a guard can ask about the members a
    /// file HAS rather than the ones it went looking for.
    ///
    /// Keyed by nothing: the result is a list, in source order,
    /// so two overloads are two entries rather than one name
    /// resolving twice to the first body. A name-keyed lookup is
    /// how a second, ungated overload goes invisible while the
    /// first, gated one answers for it twice (code review,
    /// #1078).
    ///
    /// `var` and `let` are walked beside `func` because a
    /// computed property opens a body too, and a guard that
    /// watches only `func` is blind to the shape half the
    /// members of an `enum` namespace use.
    ///
    /// **Residue, stated because it fails OPEN**: a body reached
    /// through `=` is not one — a stored property initialised
    /// from a closure (`let x = { … }()`) reads as body-less
    /// here, deliberately, because the alternative is telling a
    /// multi-line array literal from a closure without types.
    /// Nested declarations are not returned either; their text
    /// belongs to the body that encloses them, which is the
    /// scope a needle should be asking about anyway.
    static func memberBodies(
        in text: String
    ) -> [(declaration: String, body: String)] {
        let characters = Array(text)
        var found: [(declaration: String, body: String)] = []
        var index = 0
        while index < characters.count {
            guard
                let keyword = ["func ", "var ", "let "].first(
                    where: { starts(characters, at: index, $0) }
                )
            else {
                index += 1
                continue
            }
            var cursor = index + keyword.count
            let name = String(
                characters[cursor...].prefix {
                    isIdentifier($0, orDot: false)
                }
            )
            cursor += name.count
            // The parameter list, so a defaulted closure inside
            // it cannot be mistaken for the body.
            if cursor < characters.count, characters[cursor] == "(" {
                _ = balanced(
                    characters,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            }
            while cursor < characters.count,
                characters[cursor] != "{",
                characters[cursor] != "="
            {
                cursor += 1
            }
            guard cursor < characters.count,
                characters[cursor] == "{",
                let body = balanced(
                    characters,
                    from: &cursor,
                    open: "{",
                    close: "}"
                )
            else {
                index += keyword.count
                continue
            }
            found.append((name, body))
            index = cursor
        }
        return found
    }

    /// Whether `needle` begins at `index`, with a boundary.
    private static func starts(
        _ text: [Character],
        at index: Int,
        _ needle: String
    ) -> Bool {
        let characters = Array(needle)
        guard index + characters.count <= text.count,
            Array(text[index..<(index + characters.count)])
                == characters
        else { return false }
        guard index > 0 else { return true }
        return !isIdentifier(text[index - 1], orDot: false)
    }
}
