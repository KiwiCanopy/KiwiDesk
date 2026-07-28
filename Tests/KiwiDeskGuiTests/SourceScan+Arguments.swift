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
    /// single spaces (string- and nesting-aware).
    private static func firstArgument(of args: String) -> String {
        var depth = 0
        var inString = false
        var result = ""
        var previous: Character?
        for character in args {
            if inString {
                result.append(character)
                if character == "\"", previous != "\\" {
                    inString = false
                }
                previous = character
                continue
            }
            switch character {
            case "\"":
                inString = true
            case "(", "[", "{":
                depth += 1
            case ")", "]", "}":
                depth -= 1
            case ",":
                if depth == 0 {
                    return normalize(result)
                }
            default:
                break
            }
            result.append(character)
            previous = character
        }
        return normalize(result)
    }

    private static func normalize(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .replacingOccurrences(of: " .", with: ".")
    }
}
