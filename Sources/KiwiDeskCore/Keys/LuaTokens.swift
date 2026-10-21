import Foundation

/// A coarse Lua token stream for `LuaUpvalueLiterals` (#2485):
/// names, literals and punctuation, comments dropped. It answers
/// which names a chunk declares or assigns, and errs toward
/// "assigned" — a false answer there only keeps a raw body.
enum LuaTokens {
    enum Kind { case word, literal, punct }

    struct Token {
        let kind: Kind
        let text: String
        /// Character offsets into the lexed text.
        let start: Int
        let end: Int
    }

    private static let twoChar: Set<String> = [
        "==", "~=", "<=", ">=", "..", "::", "//", "<<", ">>",
    ]

    /// `\r\n` is one `Character` that is not `\n`, so it is read
    /// as `\n` here, or a line comment would run to the file's end.
    static func lex(_ text: [Character]) -> [Token] {
        let chars = text.map { $0 == "\r\n" ? "\n" : $0 }
        var tokens: [Token] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if let next = LuaBindingBody.skipTrivia(chars, i) {
                if c != "-" {
                    tokens.append(token(.literal, chars, i, next))
                }
                i = max(next, i + 1)
            } else if LuaBindingBody.isWordStart(c) {
                let (word, next) = LuaBindingBody.readWord(chars, i)
                tokens.append(
                    Token(
                        kind: .word,
                        text: word,
                        start: i,
                        end: next
                    )
                )
                i = next
            } else if c.isNumber {
                var j = i
                while j < chars.count,
                    LuaBindingBody.isWordChar(chars[j])
                        || chars[j] == "."
                {
                    j += 1
                }
                tokens.append(token(.literal, chars, i, j))
                i = j
            } else if LuaBindingBody.isSpace(c) {
                i += 1
            } else {
                let pair =
                    i + 1 < chars.count
                    ? String(chars[i...i + 1]) : ""
                let end = twoChar.contains(pair) ? i + 2 : i + 1
                tokens.append(token(.punct, chars, i, end))
                i = end
            }
        }
        return tokens
    }

    private static func token(
        _ kind: Kind,
        _ chars: [Character],
        _ start: Int,
        _ end: Int
    ) -> Token {
        Token(
            kind: kind,
            text: String(chars[start..<end]),
            start: start,
            end: end
        )
    }

    /// Whether the name at `k` is a field or method (`t.i`, `t:i`),
    /// a label or a table constructor's key (`{ i = 1 }`), never a
    /// variable read.
    static func isField(_ tokens: [Token], _ k: Int) -> Bool {
        guard k > 0 else { return false }
        let prev = tokens[k - 1].text
        if [".", ":", "::", "goto"].contains(prev) { return true }
        let next = k + 1 < tokens.count ? tokens[k + 1].text : nil
        return ["{", ",", ";"].contains(prev) && next == "="
    }

    /// Names a `local`, a Lua 5.5 `global`, a `for` header or a
    /// function's parameter list introduces.
    static func declared(_ tokens: [Token]) -> Set<String> {
        var names: Set<String> = []
        for (k, token) in tokens.enumerated() {
            switch token.text {
            case "local", "global", "for":
                names.formUnion(nameList(tokens, from: k + 1))
            case "function":
                var j = k + 1
                while j < tokens.count, tokens[j].text != "(" {
                    j += 1
                }
                names.formUnion(nameList(tokens, from: j + 1))
            default:
                break
            }
        }
        return names
    }

    /// `a, b <const>, c` from `from`, skipping `local function`
    /// and a leading attribute (`local <const> a`).
    private static func nameList(
        _ tokens: [Token],
        from: Int
    ) -> Set<String> {
        var names: Set<String> = []
        var j = from
        if j < tokens.count, tokens[j].text == "function" { j += 1 }
        if j + 2 < tokens.count, tokens[j].text == "<" { j += 3 }
        while j < tokens.count, tokens[j].kind == .word {
            names.insert(tokens[j].text)
            j += 1
            if j + 2 < tokens.count, tokens[j].text == "<" {
                j += 3
            }
            guard j < tokens.count, tokens[j].text == "," else {
                break
            }
            j += 1
        }
        return names
    }

    /// Plain names a statement assigns: the targets left of an
    /// `=` that no `local` or `for` declares, outside a table
    /// constructor, and a non-local `function name()`.
    static func assigned(_ tokens: [Token]) -> Set<String> {
        var names: Set<String> = []
        for (k, token) in tokens.enumerated() {
            if token.text == "function", k + 2 < tokens.count,
                tokens[k + 1].kind == .word,
                tokens[k + 2].text == "(",
                k == 0 || tokens[k - 1].text != "local"
            {
                names.insert(tokens[k + 1].text)
            }
            guard token.text == "=" else { continue }
            names.formUnion(targets(tokens, before: k))
        }
        return names
    }

    private static func targets(
        _ tokens: [Token],
        before k: Int
    ) -> Set<String> {
        var plain: Set<String> = []
        var j = k - 1
        while true {
            guard j >= 0, let (start, name) = element(tokens, endingAt: j)
            else { return [] }
            if let name { plain.insert(name) }
            j = start - 1
            guard j >= 0, tokens[j].text == "," else { break }
            j -= 1
        }
        let boundary = j >= 0 ? tokens[j].text : nil
        switch boundary {
        case "local", "for", "{", ",":
            return []
        default:
            return plain
        }
    }

    /// The prefix expression ending at `end` — `a`, `t.x`,
    /// `f(a)[i]`, an attribute `<const>` skipped — as its first
    /// index, and its name when it is a plain one.
    private static func element(
        _ tokens: [Token],
        endingAt end: Int
    ) -> (start: Int, name: String?)? {
        var j = end
        if j >= 2, tokens[j].text == ">", tokens[j - 2].text == "<" {
            j -= 3
        }
        let last = j
        while j >= 0 {
            if tokens[j].kind == .word {
                j -= 1
                guard j >= 0, [".", ":"].contains(tokens[j].text)
                else { break }
                j -= 1
            } else if [")", "]"].contains(tokens[j].text),
                let open = opening(tokens, closing: j)
            {
                j = open - 1
                guard j >= 0,
                    tokens[j].kind == .word
                        || [")", "]"].contains(tokens[j].text)
                else { break }
            } else {
                break
            }
        }
        guard j < last else { return nil }
        let start = j + 1
        let name =
            start == last && tokens[start].kind == .word
            ? tokens[start].text : nil
        return (start, name)
    }

    private static func opening(
        _ tokens: [Token],
        closing: Int
    ) -> Int? {
        let close = tokens[closing].text
        let open = close == ")" ? "(" : "["
        var depth = 0
        var j = closing
        while j >= 0 {
            if tokens[j].text == close { depth += 1 }
            if tokens[j].text == open {
                depth -= 1
                if depth == 0 { return j }
            }
            j -= 1
        }
        return nil
    }
}
