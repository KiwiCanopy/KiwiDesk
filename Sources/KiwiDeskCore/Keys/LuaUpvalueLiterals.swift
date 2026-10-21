import Foundation

/// Spells a recovered binding body's scalar upvalues as their
/// literals (#2485), so a loop-built `focus_space(i)` reads
/// `focus_space(3)`. All or nothing: the raw body comes back when
/// any upvalue it reads is not a string, number or boolean, when
/// the body declares one of those names, or when the source file
/// assigns one anywhere — a value that can change after the bind
/// is never shown as fact.
enum LuaUpvalueLiterals {
    /// `upvalues` maps each upvalue name to its value, nil for a
    /// non-scalar (`LuaInterpreter.functionUpvalues`); `file` is
    /// the source the function was loaded from.
    static func resolve(
        body: String,
        upvalues: [String: LuaValue?],
        file: String
    ) -> String {
        let chars = Array(body)
        let tokens = LuaTokens.lex(chars)
        var reads: [(token: LuaTokens.Token, literal: String)] = []
        for (k, token) in tokens.enumerated() {
            guard token.kind == .word,
                let entry = upvalues[token.text],
                !LuaTokens.isField(tokens, k)
            else { continue }
            guard let value = entry,
                let literal = literal(for: value, in: tokens, at: k)
            else { return body }
            reads.append((token, literal))
        }
        guard !reads.isEmpty else { return body }
        let names = Set(reads.map(\.token.text))
        guard LuaTokens.declared(tokens).isDisjoint(with: names),
            LuaTokens.assigned(LuaTokens.lex(Array(file)))
                .isDisjoint(with: names)
        else { return body }
        var out = chars
        for read in reads.reversed() {
            out.replaceSubrange(
                read.token.start..<read.token.end,
                with: Array(read.literal)
            )
        }
        return String(out)
    }

    /// The value's Lua spelling, parenthesised where the next
    /// token would otherwise read it as part of a longer token
    /// (`3..x`, `"a":upper()`, `x--3`). Nil for a non-finite
    /// number, which has no literal.
    private static func literal(
        for value: LuaValue,
        in tokens: [LuaTokens.Token],
        at k: Int
    ) -> String? {
        let text: String
        switch value {
        case .bool(let b):
            text = b ? "true" : "false"
        case .number(let n):
            guard n.isFinite else { return nil }
            if n == n.rounded(), abs(n) < 9_007_199_254_740_992 {
                text = String(Int64(n))
            } else {
                text = "\(n)"
            }
        case .string(let s):
            text = quoted(s)
        default:
            return nil
        }
        let next = k + 1 < tokens.count ? tokens[k + 1] : nil
        let prev = k > 0 ? tokens[k - 1].text : nil
        let adjoins = next.map {
            $0.kind == .literal
                || [".", ":", "[", "(", "{", ".."].contains($0.text)
        }
        let negative =
            text.hasPrefix("-")
            && (!["(", ",", "=", "{", nil].contains(prev)
                || next?.text == "^")
        return adjoins == true || negative ? "(\(text))" : text
    }

    private static func quoted(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    out += String(format: "\\%03d", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}
