import Foundation

/// Stateless primitives shared by the source-scanning parity
/// guards: the catalog guards (`SettingsCatalogSiteTests`,
/// `SettingsCatalogArgumentTests`,
/// `SettingsAnchorPrimitiveTests`), `DiscardGateParityTests`,
/// `GreyOutParityTests`, and the two bounds-routing guards
/// (`VisibleBoundsRoutingTests`, `LayoutBoundsRoutingTests`) —
/// which scan `Sources/KiwiDeskCore`, not the GUI tree, and live
/// here only because this helper does.
///
/// Ratified as a third shared test primitive under AGENTS.md §5
/// ("Split test suites early") and `.claude/rules/tests.md`, on
/// their own bar — **drift risk, not copy count**. `balanced` and
/// `swiftSources` were byte-identical in both suites, and the
/// named harm is concrete: harden the walker in one copy and not
/// the other (raw strings, multiline literals, interpolation) and
/// the *over*-matching copy silently swallows call sites its
/// guard was meant to catch. A guard that passes for the wrong
/// reason is the exact failure both suites exist to prevent.
/// Stateless, no setup/teardown, no assertions of its own —
/// the same shape as `ReflectionParity` and `ScriptFixture`.
enum SourceScan {
    /// Consumes whitespace then a balanced `open`…`close` run,
    /// returning its interior and advancing `cursor` past it.
    /// String literals are skipped so a brace or paren inside
    /// one cannot unbalance the walk.
    ///
    /// Known limits, all of which fail **shut** (a false red,
    /// never a silent pass): `"""` multiline literals and raw
    /// string delimiters desync the quote skip. No source in
    /// the scanned trees uses either shape today.
    static func balanced(
        _ text: [Character],
        from cursor: inout Int,
        open: Character,
        close: Character
    ) -> String? {
        var i = cursor
        while i < text.count, text[i].isWhitespace { i += 1 }
        guard i < text.count, text[i] == open else { return nil }
        var depth = 0
        let start = i + 1
        while i < text.count {
            let character = text[i]
            if character == "\"" {
                i += 1
                while i < text.count, text[i] != "\"" {
                    if text[i] == "\\" { i += 1 }
                    i += 1
                }
            } else if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    cursor = i + 1
                    return String(text[start..<i])
                }
            }
            i += 1
        }
        return nil
    }

    /// Cuts each line at its first `//`, then removes `/* … */`
    /// spans. Note the direction depends on the
    /// consumer: for a *counting* guard a mis-cut erases a call
    /// and so fails OPEN, where for the balanced-walker consumers
    /// below it fails shut, as a mystifying red rather than a
    /// silent pass.
    ///
    /// The block half is not decoration: this used to say the
    /// repo has "no `/* */` convention" and stop at `//`, which
    /// made every positive needle in every consumer satisfiable
    /// by commenting the call out in block form — a guard-prover
    /// run deleted an `.accessibilityHidden` modifier, restated
    /// it as `/* … */`, and the needle stayed green over a view
    /// that had shipped the defect. A convention nobody follows
    /// is not a guarantee; the stripper is what has to hold.
    ///
    /// Line comments go first, and the order is load-bearing: a
    /// doc comment may legitimately contain `/*` (a glob such as
    /// `Resources/Locales/*.json` does), and stripping blocks
    /// first would open a comment there and swallow source until
    /// the next `*/`.
    ///
    /// The block half skips string literals; the LINE half does
    /// not, and that residue predates this and stays: a `//`
    /// inside a literal cuts the rest of that one line. It is
    /// not hypothetical — `ServiceManager.swift` carries two (a
    /// plist DOCTYPE and a URL) — and it is harmless to every
    /// current consumer only because no needle follows them on
    /// the same line, which is luck rather than design. Weigh it
    /// when adding a needle. What that residue must NOT do is
    /// widen: an unbalanced quote it leaves behind used to send
    /// the block walk to EOF, which is why `close` refuses an
    /// unterminated literal.
    ///
    /// `SourceScanCommentTests` holds the whole-file property
    /// this once broke — every line carrying no comment marker
    /// survives verbatim — because a scan handed less source
    /// than it thinks cannot red on its own.
    static func stripComments(_ source: String) -> String {
        let lined =
            source
            .split(
                separator: "\n",
                omittingEmptySubsequences: false
            )
            .map { line -> Substring in
                if let slash = line.range(of: "//") {
                    return line[..<slash.lowerBound]
                }
                return line
            }
            .joined(separator: "\n")
        return stripBlockComments(lined)
    }

    /// Removes each `/* … */` span, keeping the newlines inside
    /// it so line-based consumers still count lines correctly.
    ///
    /// **Skips string literals**, and that is the whole reason
    /// this is a character walk rather than a `range(of:)` loop.
    /// A naive walk truncated three suites in `Tests/` the day it
    /// landed — `entry.hasSuffix("/**")`,
    /// `"Sources/KiwiDeskCore/*"` and `#""$LOCALES"/*.json"#` each
    /// open a block comment that never closes — and one of them
    /// was this file, whose own `"/*"` and `"*/"` literals blanked
    /// 146 characters of the function you are reading. A
    /// forbidding or counting scan cannot red for having read
    /// less, so all of it was silent.
    ///
    /// Spans **nest**, as they do in Swift, so
    /// `/* outer /* inner */ tail */` leaves nothing behind
    /// rather than stranding `tail */` for a needle to match.
    /// An unterminated `/*` outside a literal takes the rest of
    /// the file, which is what the compiler does with it too.
    private static func stripBlockComments(
        _ source: String
    ) -> String {
        var out = ""
        var depth = 0
        let text = Array(source)
        var i = 0
        while i < text.count {
            if depth == 0, let end = literalEnd(text, from: i) {
                out += String(text[i..<end])
                i = end
                continue
            }
            if matches(text, at: i, openSpan) {
                depth += 1
                i += 2
                continue
            }
            if depth > 0, matches(text, at: i, closeSpan) {
                depth -= 1
                i += 2
                continue
            }
            // Newlines inside a span are kept so a line-based
            // consumer still counts the file's real lines.
            if depth == 0 || text[i] == "\n" {
                out.append(text[i])
            }
            i += 1
        }
        return out
    }

    /// The index just past the string literal starting at `i`, or
    /// nil when nothing starts there. Handles the three shapes
    /// the scanned trees use — `"…"` with escapes, `"""…"""`, and
    /// the raw `#"…"#` — because each of them can legally carry a
    /// `/*` that is not a comment.
    private static func literalEnd(
        _ text: [Character],
        from i: Int
    ) -> Int? {
        if matches(text, at: i, rawQuote) {
            return close(
                text,
                from: i + 2,
                on: rawEnd,
                escaped: false
            )
        }
        if matches(text, at: i, tripleQuote) {
            return close(
                text,
                from: i + 3,
                on: tripleQuote,
                escaped: true
            )
        }
        if text[i] == "\"" {
            return close(text, from: i + 1, on: quote, escaped: true)
        }
        return nil
    }

    /// Scans to `delimiter`, honouring `\` escapes when the shape
    /// has them. **Nil when the delimiter never arrives**, so the
    /// caller treats the quote as an ordinary character and keeps
    /// stripping.
    ///
    /// That arm is not defensive coding, it is the fix for a
    /// defect this file's own line half creates: the line pass
    /// cuts `"https://…"` at the `//` and leaves the opening
    /// quote unbalanced, so a literal walk that ran to EOF would
    /// copy the rest of the file verbatim and strip no comments
    /// in it at all. Seven files in `Sources/` are in exactly
    /// that state, two of them in trees the Settings guards scan.
    private static func close(
        _ text: [Character],
        from start: Int,
        on delimiter: [Character],
        escaped: Bool
    ) -> Int? {
        var i = start
        while i < text.count {
            if escaped, text[i] == "\\" {
                i += 2
                continue
            }
            if matches(text, at: i, delimiter) {
                return i + delimiter.count
            }
            i += 1
        }
        return nil
    }

    /// Takes the needle as characters rather than a `String`:
    /// this runs up to twice per character of every file every
    /// scan guard reads, and an `Array(needle)` inside it cost
    /// millions of small allocations per suite.
    private static func matches(
        _ text: [Character],
        at i: Int,
        _ needle: [Character]
    ) -> Bool {
        guard i + needle.count <= text.count else { return false }
        for (offset, character) in needle.enumerated()
        where text[i + offset] != character {
            return false
        }
        return true
    }

    private static let openSpan: [Character] = ["/", "*"]
    private static let closeSpan: [Character] = ["*", "/"]
    private static let rawQuote: [Character] = ["#", "\""]
    private static let rawEnd: [Character] = ["\"", "#"]
    private static let tripleQuote: [Character] = ["\"", "\"", "\""]
    private static let quote: [Character] = ["\""]

    static func swiftSources(
        under directory: URL
    ) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        return files
    }

    /// The repo root, derived from a test file's own path.
    static func repoRoot(from filePath: String) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }
}

extension String {
    /// Non-overlapping occurrences of `needle`.
    func occurrences(of needle: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var total = 0
        var cursor = startIndex
        while let found = range(
            of: needle,
            range: cursor..<endIndex
        ) {
            total += 1
            cursor = found.upperBound
        }
        return total
    }
}
