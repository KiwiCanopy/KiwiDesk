import Foundation

// Which type encloses a given line, for guards that scan a
// declaration rather than a call.
//
// Here rather than inside its one consumer for the reason the
// family exists (AGENTS.md §5, `.claude/rules/tests.md`) — and
// the drift argument is the sharper one, not the copy count:
// `SourceScan.balanced` already walks braces while skipping
// string literals, so a privately-owned second quote-aware brace
// walker in the same target is exactly the "harden one copy and
// not the other" harm. It also carries the same documented
// limits, in one place, where the next reader of either will
// find them.
extension SourceScan {
    /// The type enclosing every line of `lines`, one entry per
    /// line, `nil` where nothing encloses it (a file's imports,
    /// a free function).
    ///
    /// A **forward** walk carrying a brace-depth type stack.
    /// Walking backwards to the nearest preceding declaration is
    /// the obvious shortcut and is wrong: it reads a closed
    /// *sibling* as the owner. `BorderManager.Spec` is declared
    /// above `BorderManager.onLog`, and the first draft of
    /// `LogSeamWiringTests` reported that seam's owner as `Spec`
    /// — a red on a healthy tree, which is how a guard gets
    /// weakened into silence.
    ///
    /// `extension` and `protocol` push like any other type, so a
    /// member declared in either resolves to that name.
    ///
    /// Same limits as `balanced`, and they matter more here
    /// because a desync silently mis-attributes rather than
    /// failing to match: `"""` literals and raw string
    /// delimiters desync the quote skip, so braces inside one are
    /// counted as code. `inString` resets per line, so a
    /// single-line desync cannot escape that line, and no file
    /// carrying a `var onLog` uses either shape today.
    static func enclosingTypes(of lines: [Substring]) -> [String?] {
        let declaration = try? NSRegularExpression(
            pattern:
                #"(?:^|\s)(?:class|struct|actor|enum|extension"#
                + #"|protocol)\s+([A-Za-z_][A-Za-z0-9_]*)"#
        )
        var enclosing: [String?] = []
        var stack: [(name: String, depth: Int)] = []
        var pending: String?
        var depth = 0
        for line in lines {
            enclosing.append(stack.last?.name)
            let text = String(line)
            if let declaration,
                let match = declaration.firstMatch(
                    in: text,
                    range: NSRange(text.startIndex..., in: text)
                ),
                let range = Range(match.range(at: 1), in: text)
            {
                // A declaration whose brace opens on a later
                // line stays pending until it does.
                pending = String(text[range])
            }
            var inString = false
            var escaped = false
            for character in line {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                } else if inString {
                    continue
                } else if character == "{" {
                    depth += 1
                    if let name = pending {
                        stack.append((name, depth))
                        pending = nil
                    }
                } else if character == "}" {
                    if stack.last?.depth == depth {
                        stack.removeLast()
                    }
                    depth -= 1
                }
            }
        }
        return enclosing
    }
}
