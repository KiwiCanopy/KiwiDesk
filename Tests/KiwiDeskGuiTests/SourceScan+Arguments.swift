import Foundation

// The call-shape walker shared by the two guard families that
// ask "what is this primitive being FED?" — the catalog site
// guards (`SettingsCatalogArgumentTests`: is a section's first
// argument a catalog declaration?) and the anchor primitive
// guards (`SettingsAnchorPrimitiveTests`: are a shape's two
// reveal halves fed one matching control?).
//
// Here rather than copied per suite on the standing bar in
// `.claude/rules/tests.md` — drift risk, not copy count. Both
// families assert on the *text of an argument expression*, so a
// copy that normalizes differently (a line break inside a dotted
// path, a nested call, an interpolated literal) makes its guard
// read a different string from the same source and pass for the
// wrong reason. Stateless, no assertions of its own.
extension SourceScan {
    /// The first argument expression of every `needle(` call in
    /// `source`, whitespace-normalized. `needle` includes its
    /// opening paren (`".searchAnchor("`), so a leading dot
    /// distinguishes an application from a declaration.
    static func firstArguments(
        of needle: String,
        in source: String
    ) -> [String] {
        let text = Array(source)
        let wanted = Array(needle)
        var out: [String] = []
        var i = 0
        while i + wanted.count <= text.count {
            guard Array(text[i..<(i + wanted.count)]) == wanted
            else {
                i += 1
                continue
            }
            var cursor = i + wanted.count - 1
            guard
                let args = balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                i += wanted.count
                continue
            }
            out.append(firstArgument(of: args))
            i = cursor
        }
        return out
    }

    /// Everything before the first top-level comma, collapsed to
    /// single spaces — `topLevelArguments`' first element.
    /// Internal: `ReduceMotionGateTests` reads the animation
    /// argument through it (#1069).
    static func firstArgument(of args: String) -> String {
        normalize(topLevelArguments(of: args)[0])
    }

    /// `args` split at its top-level commas, each argument
    /// verbatim: nesting-aware, and literal-aware through
    /// `literal(_:from:)`, so a comma inside `"…"`, `"""…"""` or
    /// `#"…"#` never splits. The family's one splitter (#1899).
    /// Never empty: no argument text reads as one empty argument.
    static func topLevelArguments(of args: String) -> [String] {
        let text = Array(args)
        var depth = 0
        var arguments: [String] = [""]
        var index = 0
        while index < text.count {
            if let literal = literal(text, from: index) {
                arguments[arguments.count - 1]
                    .append(contentsOf: text[index..<literal.end])
                index = literal.end
                continue
            }
            switch text[index] {
            case "(", "[", "{": depth += 1
            case ")", "]", "}": depth -= 1
            case "," where depth == 0:
                arguments.append("")
                index += 1
                continue
            default: break
            }
            arguments[arguments.count - 1].append(text[index])
            index += 1
        }
        return arguments
    }

    private static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .replacingOccurrences(of: " .", with: ".")
    }
}
