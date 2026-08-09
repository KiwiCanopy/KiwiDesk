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
    /// Neither half respects string literals, and the residue is
    /// stated rather than chased because the direction differs by
    /// consumer: a `/*` inside a literal blanks the rest of the
    /// file, which reds a positive needle loudly and lets a
    /// forbidding or counting scan pass SILENTLY. `Sources/`
    /// carries no `/* */` span and no unbalanced opener at all
    /// (audited 2026-08-09), so this is latent rather than live —
    /// weigh it when a needle follows a literal on one line.
    ///
    /// A `//` inside a string literal is what triggers it, and it
    /// is NOT hypothetical: `ServiceManager.swift` carries two (a
    /// plist DOCTYPE and a URL). That file is harmless to every
    /// current consumer because no guard needle follows them on
    /// the same line — which is luck, not design, so weigh it
    /// when adding a needle.
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
    /// An unterminated `/*` takes the rest of the file, which is
    /// what the compiler does with it too.
    private static func stripBlockComments(
        _ source: String
    ) -> String {
        var out = ""
        var rest = Substring(source)
        while let open = rest.range(of: "/*") {
            out += rest[..<open.lowerBound]
            let after = rest[open.upperBound...]
            guard let close = after.range(of: "*/") else {
                return out
            }
            out += after[..<close.lowerBound]
                .filter { $0 == "\n" }
            rest = after[close.upperBound...]
        }
        return out + rest
    }

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
