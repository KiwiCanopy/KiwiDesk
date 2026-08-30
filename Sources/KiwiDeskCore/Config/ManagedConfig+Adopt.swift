import Foundation

/// Generates adopted `init.lua` commenting out GUI-managed statements (#55,
/// #355).
extension ManagedConfig {
    public static func adopt(
        original: String,
        date: String
    ) -> String {
        let header = adoptHeader(date: date)
        let body =
            selectivelyCommented(original)
            ?? commentedEverything(original)
        let result = header + "\n" + body + "\n"
        // Fall back to commenting everything if foreign tokens remain.
        if hasForeignCode(result) {
            return header + "\n"
                + commentedEverything(original) + "\n"
        }
        return result
    }

    /// Selectively comments out managed statements while keeping custom Lua
    /// live (#355).
    static func selectivelyCommented(_ source: String) -> String? {
        let lines = source.components(separatedBy: "\n")
        var out: [String] = []
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmedLua
            if trimmed.isEmpty || trimmed.hasPrefix("--") {
                out.append(lines[i])
                i += 1
                continue
            }
            guard let end = statementSpan(lines, from: i) else {
                return nil
            }
            let block = Array(lines[i..<end])
            if blockIsManaged(block) {
                out.append(contentsOf: block.map(commentLine))
            } else {
                out.append(contentsOf: block)
            }
            i = end
        }
        return out.joined(separator: "\n")
    }

    /// End index of statement starting at `from` tracked via block depth.
    static func statementSpan(
        _ lines: [String],
        from start: Int
    ) -> Int? {
        var depth = 0
        var j = start
        repeat {
            depth += depthDelta(codeOnly(lines[j]))
            if depth < 0 { return nil }
            j += 1
        } while depth > 0 && j < lines.count
        return depth == 0 ? j : nil
    }

    /// True if block begins with a managed declaration (#355).
    static func blockIsManaged(_ block: [String]) -> Bool {
        for line in block {
            let t = line.trimmedLua
            if t.isEmpty || t.hasPrefix("--") { continue }
            return lineDeclaresManaged(t)
        }
        return false
    }

    /// Bracket and keyword depth delta for a line of code.
    static func depthDelta(_ code: String) -> Int {
        var depth = 0
        for ch in code {
            if ch == "(" || ch == "{" { depth += 1 }
            if ch == ")" || ch == "}" { depth -= 1 }
        }
        depth += keywordCount(
            code,
            [
                "function", "if", "for",
                "while", "repeat",
            ]
        )
        depth -= keywordCount(code, ["end", "until"])
        return depth
    }

    /// Count of whole-word occurrences of any keyword in `code`.
    static func keywordCount(
        _ code: String,
        _ keywords: [String]
    ) -> Int {
        var total = 0
        for word in keywords {
            let pattern = #"\b"# + word + #"\b"#
            let range = NSRange(code.startIndex..., in: code)
            if let regex = try? NSRegularExpression(
                pattern: pattern
            ) {
                total += regex.numberOfMatches(
                    in: code,
                    range: range
                )
            }
        }
        return total
    }

    /// The line with string literals and the trailing line comment
    /// removed, so their brackets/keywords never skew the depth
    /// count. A single-pass scanner: characters inside `"…"`/`'…'`
    /// are dropped (escapes respected), and `--` outside a string
    /// ends the line. Long-bracket strings/comments (`[[ … ]]`)
    /// are not modeled — if one appears, a miscount at worst trips
    /// the fallback.
    static func codeOnly(_ line: String) -> String {
        var out = ""
        var quote: Character?
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if let open = quote {
                if ch == "\\" {
                    i += 2
                    continue
                }
                if ch == open { quote = nil }
                i += 1
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                i += 1
                continue
            }
            if ch == "-", i + 1 < chars.count,
                chars[i + 1] == "-"
            {
                break
            }
            out.append(ch)
            i += 1
        }
        return out
    }

    /// Fallback that comments out the full source line-by-line.
    static func commentedEverything(_ source: String) -> String {
        source
            .components(separatedBy: "\n")
            .map(commentLine)
            .joined(separator: "\n")
    }

    private static func commentLine(_ line: String) -> String {
        line.isEmpty ? "--" : "-- " + line
    }

    private static func adoptHeader(date: String) -> String {
        [
            "-- Adopted by KiwiDesk on " + date + ".",
            "-- The app now manages your settings, rules, and "
                + "keybindings",
            "-- itself (gui.json); the migrated lines are "
                + "commented out",
            "-- below as a backup, and recovered keybindings "
                + "appear in the",
            "-- Keybindings tab. Your custom Lua (event hooks, "
                + "helpers) is",
            "-- kept active where possible — delete the commented "
                + "backup",
            "-- once you no longer need it.",
        ].joined(separator: "\n")
    }
}

extension StringProtocol {
    /// Trim used by the adopt scanner (the `trimmed` in
    /// `ManagedConfig.swift` is file-private).
    fileprivate var trimmedLua: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
