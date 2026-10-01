import Foundation

// Which type encloses a given line, for guards that scan a
// declaration rather than a call.
//
// A reading OF `scopeTree`, never a brace walk of its own: two
// walkers in the family are the "harden one copy and not the
// other" harm (tests.md ▸ source-scanning primitives). The tree
// walks blanked source, so a brace or type keyword inside a
// literal or comment is never counted, and
// `SourceScanScopesTests` ▸ `nothingGoesDark` holds it to every
// type declaration in both Sources trees.
extension SourceScan {
    private static let typeKeywords: Set<String> = [
        "class", "struct", "enum", "actor", "extension", "protocol",
    ]

    /// The type enclosing every line of `lines`, one entry per
    /// line, `nil` where nothing encloses it (a file's imports,
    /// a free function).
    ///
    /// Each line reads the scope open at its FIRST character, so
    /// a declaration line answers its outer type and its closing
    /// `}` line the type it closes. Walking backwards to the
    /// nearest preceding declaration is the obvious shortcut and
    /// is wrong: it reads a closed *sibling* as the owner — the
    /// first draft of `LogSeamWiringTests` reported
    /// `BorderManager.onLog`'s owner as `Spec`, declared above it.
    ///
    /// `extension` and `protocol` count as types, so a member
    /// declared in either resolves to that name; functions and
    /// closures are transparent.
    static func enclosingTypes(of lines: [Substring]) -> [String?] {
        // Offsets are read off the BLANKED text: blanking keeps
        // newlines but not UTF-16 length inside a literal.
        let text =
            blankingCommentsAndLiterals(lines.joined(separator: "\n"))
            as NSString
        let tree = scopeTree(of: text)
        var enclosing: [String?] = []
        var start = 0
        for _ in lines {
            var cursor = tree.innermost[start]
            while let index = cursor,
                !typeKeywords.contains(tree.scopes[index].keyword)
            {
                cursor = tree.scopes[index].parent
            }
            enclosing.append(cursor.map { tree.scopes[$0].name })
            let rest = NSRange(
                location: start,
                length: text.length - start
            )
            let newline = text.range(of: "\n", range: rest)
            start =
                newline.location == NSNotFound
                ? text.length : newline.location + 1
        }
        return enclosing
    }
}
