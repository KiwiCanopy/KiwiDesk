import Foundation

/// Extracts the body of a bound `function() ... end` literal from
/// its source range, so a keybinding's action text can be
/// recovered from init.lua (#4).
///
/// `debug.getinfo` reports only the line range of a function, not
/// its columns, so the slice for `KiwiDesk.bind("alt+h",
/// function() KiwiDesk.focus("left") end)` still holds the whole
/// call. This scanner walks that slice — skipping strings and
/// comments so their contents never count as syntax — to find the
/// `function` header, then the matching `end`, and returns the
/// text between them (dedented; the writer re-indents).
///
/// Block depth uses the classic Lua-lexer trick: `function`, `if`,
/// and `do` each open a block closed by `end`, while `for`/`while`
/// are opened by their own `do` and so are not counted. This
/// covers plain literals and multi-statement custom bodies; it
/// does not evaluate the code, only balances its block keywords.
///
/// Two assumptions, both true for GUI-authored configs (each bind
/// on its own line with an inline literal) and only relevant to
/// hand-written files adopted once:
/// - The action is an inline `function() … end` literal. A bind to
///   a named handler (`KiwiDesk.bind("x", my_handler)`) has no
///   literal in range and yields nil, so that row is dropped.
/// - One function literal per source line: `debug.getinfo` reports
///   the same range for every literal sharing a line, so only the
///   first is recovered.
enum LuaBindingBody {
    /// Slices the 1-based inclusive line range out of `source`
    /// and returns the dedented function body, or nil when the
    /// range holds no balanced `function ... end`.
    static func extract(
        from source: String,
        firstLine: Int,
        lastLine: Int
    ) -> String? {
        let normalized = source.replacingOccurrences(
            of: "\r\n",
            with: "\n"
        )
        let lines = normalized.components(separatedBy: "\n")
        guard firstLine >= 1, lastLine <= lines.count,
            firstLine <= lastLine
        else { return nil }
        let region = lines[(firstLine - 1)...(lastLine - 1)]
            .joined(separator: "\n")
        return body(in: Array(region))
    }

    // MARK: - Scanning

    /// The dedented body between the first `function` header and
    /// its matching `end` in `chars`.
    private static func body(in chars: [Character]) -> String? {
        guard let paramsEnd = functionParamsEnd(chars) else {
            return nil
        }
        var i = paramsEnd
        var depth = 1
        while i < chars.count {
            if let skip = skipTrivia(chars, i) {
                i = skip
                continue
            }
            if isWordStart(chars[i]) {
                let start = i
                let (word, next) = readWord(chars, i)
                i = next
                switch word {
                case "function", "if", "do":
                    depth += 1
                case "end":
                    depth -= 1
                    if depth == 0 {
                        return dedent(
                            String(chars[paramsEnd..<start])
                        )
                    }
                default:
                    break
                }
                continue
            }
            i += 1
        }
        return nil
    }

    /// The index just past the `)` of the first `function (...)`
    /// header, skipping any leading call syntax and its strings.
    private static func functionParamsEnd(
        _ chars: [Character]
    ) -> Int? {
        var i = 0
        while i < chars.count {
            if let skip = skipTrivia(chars, i) {
                i = skip
                continue
            }
            if isWordStart(chars[i]) {
                let (word, next) = readWord(chars, i)
                i = next
                if word == "function" {
                    return paramListEnd(chars, i)
                }
                continue
            }
            i += 1
        }
        return nil
    }

    /// The index just past the matching `)` of a `(...)` param
    /// list beginning at or after `from`.
    private static func paramListEnd(
        _ chars: [Character],
        _ from: Int
    ) -> Int? {
        var i = from
        while i < chars.count, chars[i] != "(" {
            if isSpace(chars[i]) { i += 1 } else { return nil }
        }
        guard i < chars.count else { return nil }
        var depth = 0
        while i < chars.count {
            if chars[i] == "(" { depth += 1 }
            if chars[i] == ")" {
                depth -= 1
                if depth == 0 { return i + 1 }
            }
            i += 1
        }
        return nil
    }

    // MARK: - Trivia (strings & comments)

    /// If a string or comment starts at `i`, the index just past
    /// it; otherwise nil. Keeps keyword-like text inside literals
    /// from being counted as block syntax.
    private static func skipTrivia(
        _ chars: [Character],
        _ i: Int
    ) -> Int? {
        let c = chars[i]
        if c == "-", i + 1 < chars.count, chars[i + 1] == "-" {
            return skipComment(chars, i + 2)
        }
        if c == "\"" || c == "'" {
            return skipShortString(chars, i)
        }
        if c == "[", let open = longOpen(chars, i) {
            return skipLongBracket(chars, open.afterOpen, open.level)
        }
        return nil
    }

    /// A `--` comment: a long bracket if one opens here, else to
    /// the end of the line.
    private static func skipComment(
        _ chars: [Character],
        _ i: Int
    ) -> Int {
        if i < chars.count, chars[i] == "[",
            let open = longOpen(chars, i)
        {
            return skipLongBracket(chars, open.afterOpen, open.level)
        }
        var j = i
        while j < chars.count, chars[j] != "\n" { j += 1 }
        return j
    }

    private static func skipShortString(
        _ chars: [Character],
        _ i: Int
    ) -> Int {
        let quote = chars[i]
        var j = i + 1
        while j < chars.count {
            let c = chars[j]
            if c == "\\" {
                j += 2
                continue
            }
            if c == quote { return j + 1 }
            if c == "\n" { return j }
            j += 1
        }
        return chars.count
    }

    /// The `=` level of a long-bracket opener (`[[`, `[==[`) at
    /// `i`, and the index just past it — else nil.
    private static func longOpen(
        _ chars: [Character],
        _ i: Int
    ) -> (level: Int, afterOpen: Int)? {
        guard chars[i] == "[" else { return nil }
        var k = i + 1
        var eq = 0
        while k < chars.count, chars[k] == "=" {
            eq += 1
            k += 1
        }
        guard k < chars.count, chars[k] == "[" else { return nil }
        return (eq, k + 1)
    }

    private static func skipLongBracket(
        _ chars: [Character],
        _ from: Int,
        _ level: Int
    ) -> Int {
        var j = from
        while j < chars.count {
            if chars[j] == "]" {
                var k = j + 1
                var eq = 0
                while k < chars.count, chars[k] == "=" {
                    eq += 1
                    k += 1
                }
                if eq == level, k < chars.count, chars[k] == "]" {
                    return k + 1
                }
            }
            j += 1
        }
        return chars.count
    }

    // MARK: - Words & whitespace

    private static func readWord(
        _ chars: [Character],
        _ i: Int
    ) -> (String, Int) {
        var j = i
        while j < chars.count, isWordChar(chars[j]) { j += 1 }
        return (String(chars[i..<j]), j)
    }

    private static func isWordStart(_ c: Character) -> Bool {
        c == "_" || c.isLetter
    }

    private static func isWordChar(_ c: Character) -> Bool {
        c == "_" || c.isLetter || c.isNumber
    }

    private static func isSpace(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r"
    }

    /// Trims blank edges, removes the common leading indent, and
    /// strips each line's trailing whitespace so the writer's
    /// re-indentation starts from column zero and a one-line
    /// `function() … end` doesn't keep the space before `end`.
    /// (Trailing whitespace is only meaningful inside a multi-line
    /// `[[…]]` string — vanishingly rare in a keybinding body, and
    /// the user reviews the import before saving.)
    private static func dedent(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let first = lines.first, isBlank(first) {
            lines.removeFirst()
        }
        while let last = lines.last, isBlank(last) {
            lines.removeLast()
        }
        guard !lines.isEmpty else { return "" }
        let indents = lines.filter { !isBlank($0) }.map {
            $0.prefix { $0 == " " || $0 == "\t" }.count
        }
        let common = indents.min() ?? 0
        return lines.map { line in
            isBlank(line)
                ? ""
                : trimTrailing(String(line.dropFirst(common)))
        }
        .joined(separator: "\n")
    }

    /// `line` without its trailing spaces and tabs.
    private static func trimTrailing(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex {
            let prev = line.index(before: end)
            guard line[prev] == " " || line[prev] == "\t" else {
                break
            }
            end = prev
        }
        return String(line[line.startIndex..<end])
    }

    private static func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\r" }
    }
}
