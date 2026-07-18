import Foundation

/// Builds the "adopted" `init.lua` when a hand-written config is
/// migrated into GUI management (#55/#355).
///
/// The managed statements — the settings, rules, and keybindings
/// `gui.json` now owns — are commented out as an inert, dated
/// backup. Harmless custom Lua (event hooks like `KiwiDesk.on`,
/// `print`, helper functions) is kept **live**, so integrations
/// such as the sketchybar bridge keep firing after adoption
/// instead of going silent (#355).
///
/// Correctness invariant: the result must contain **no** foreign
/// code (`managedTokens` — rules/binds/modes), or `isGuiManaged`
/// flips false and the adopt silently fails to switch ownership.
/// Two nets guarantee it — statement segmentation bails to
/// commenting everything on any structural anomaly
/// (unbalanced/never-closing spans), and the finished file is
/// re-checked with `hasForeignCode`; a positive there also falls
/// back to the full comment. Data-safe either way: the original is
/// always recoverable from the commented backup.
///
/// The invariant is stated for **foreign** code only, on purpose.
/// A `set_*` setting verb left live is benign — it neither trips
/// `hasForeignCode` (so ownership holds) nor survives: `loadConfig`
/// applies the `gui.json`/profile settings **wholesale after**
/// init.lua runs, overwriting it with the value `gui.json` already
/// owns. So `set_*` needs no backstop, and the net must NOT widen
/// to `declaresManagedSettings` — that would re-comment a live
/// hook whose body legitimately calls `set_` (the whole point of
/// #355).
///
/// Two blind spots are inherited from the token scanner and
/// accepted (see `docs/design-decisions.md`): a foreign token
/// split across physical lines (`app_rules\n= {…}`) or reached via
/// an aliased receiver (`local K = KiwiDesk; K.bind(…)`) is kept
/// live and also escapes the foreign net — rare in hand-written
/// Lua, and the backup preserves the original. Conversely, a
/// managed token mentioned only inside a **string** in otherwise
/// custom code trips the foreign net and forces the whole file to
/// the full-comment fallback (safe direction — no live foreign —
/// but it silences that file's hooks).
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
        // Correctness net: if selective commenting somehow left a
        // foreign token live, fall back to commenting everything.
        if hasForeignCode(result) {
            return header + "\n"
                + commentedEverything(original) + "\n"
        }
        return result
    }

    // MARK: - Selective commenting

    /// Comments out only the managed statements, keeping custom
    /// Lua live. Returns nil on any structural anomaly (a span
    /// that never balances), so the caller falls back to
    /// commenting the whole file.
    static func selectivelyCommented(_ source: String) -> String? {
        let lines = source.components(separatedBy: "\n")
        var out: [String] = []
        var i = 0
        while i < lines.count {
            let trimmed = lines[i].trimmedLua
            // Blank lines and full-line comments carry through
            // verbatim — they belong to no statement.
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

    /// The index one past the last line of the statement starting
    /// at `from`, found by tracking bracket + block depth until it
    /// returns to zero. Nil if the depth goes negative or the file
    /// ends mid-statement — the signal to fall back.
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

    /// A statement block is managed when its **head** — the first
    /// non-blank, non-comment line — opens a managed construct.
    /// Keying on the head (not "any line") keeps a `KiwiDesk.on`
    /// hook whose body happens to call `set_*` classified as
    /// custom, so the hook stays live (#355).
    static func blockIsManaged(_ block: [String]) -> Bool {
        for line in block {
            let t = line.trimmedLua
            if t.isEmpty || t.hasPrefix("--") { continue }
            return lineDeclaresManaged(t)
        }
        return false
    }

    // MARK: - Depth scanning

    /// The bracket + block-keyword depth change on one line of
    /// code (comments and string contents already stripped).
    /// `(`/`{` and the block openers `function`/`if`/`for`/
    /// `while`/`repeat` open; `)`/`}` and `end`/`until` close.
    /// `do`/`then` are deliberately uncounted — they pair with an
    /// already-counted `for`/`while`/`if`, so counting them would
    /// double-count. A bare `do … end` block therefore reads as
    /// unbalanced and trips the fallback, which is safe.
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

    // MARK: - Full-comment fallback

    /// The whole original commented out, line by line — the
    /// original `adopt` behavior, kept as the fallback.
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
