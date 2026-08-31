import Foundation

/// Extracts body text of an inline `function() ... end` literal
/// from Lua source line ranges (#4). Two assumptions, true for
/// GUI-authored configs: a bind to a named handler yields nil
/// (that row is dropped), and only the FIRST literal on a shared
/// source line is recovered.
enum LuaBindingBody {
    /// Extracts and dedents function body within 1-based inclusive line range.
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
