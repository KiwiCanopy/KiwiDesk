import Foundation

// Which type encloses a given line, for guards that scan a
// declaration rather than a call.
//
// A per-line reading of `scopeTree` (SourceScan+Scopes.swift),
// never a brace walk of its own: two walkers in the family are
// the "harden one copy and not the other" harm (tests.md ▸
// source-scanning primitives). That file's header names the
// canary holding the tree; `SourceScanEnclosingTypesTests` holds
// this reading of it.
extension SourceScan {
    /// The type enclosing every line of `lines`, one entry per
    /// line, `nil` where nothing encloses it (a file's imports,
    /// a free function).
    ///
    /// Each line reads the scope open at its FIRST character, so
    /// a declaration line answers its outer type and its closing
    /// `}` line the type it closes. `extension` and `protocol`
    /// count as types; functions and closures are transparent.
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
            enclosing.append(
                tree.enclosingType(at: start).map { tree.scopes[$0].name }
            )
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
