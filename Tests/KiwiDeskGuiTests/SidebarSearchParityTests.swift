import Foundation
import Testing

/// The search index is a second mirror of the subsection-title
/// list (.claude/rules/parity-tests.md): the titles live once
/// at their `SettingsSection(...)` call sites and once in
/// `SidebarSearch.subsections(of:)`. Two source-scanning
/// guards close both drift directions — a header removed or
/// renamed in a view (stale index key), and a header added to
/// a view but never indexed (silent search gap) —
/// `extract-keys --check` pins the third axis (same key must
/// carry the same English everywhere).
///
/// Known limit of a source scan: it cannot see the view tree,
/// so a header key that MOVES to a different destination than
/// the index claims passes both guards and search points at
/// the old tab. Accepted at tier 1 (#277's per-control catalog
/// revisits); keep it in mind when relocating sections.
@Suite("Sidebar search index parity")
struct SidebarSearchParityTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private var settingsDir: URL {
        repoRoot.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
    }

    /// Headers deliberately absent from the index: fail-shut —
    /// a NEW one is either indexed or added here consciously.
    private let unindexed: Set<String> = [
        // Computed per-layout title ("%1$@ bar"), deferred to
        // the #277 per-control catalog.
        "app_bar.layout.title",
        // The per-layout override drawer, inside that same
        // computed-title section — indexing the child while its
        // parent is deferred would point search at a header the
        // result caption cannot name.
        "app_bar.layout.overrides",
        // Two reasons, and the second is the durable one.
        // (a) It lives in the per-Space "Overrides…" popover,
        // reachable from a row button rather than a destination,
        // so search has nowhere to send the user. That is a
        // stronger bar than the `.bars` precedent, where a hit
        // one click behind a local switch IS indexed — a popover
        // is not a switch. (b) The string is "Saved for other
        // layouts (%1$d)", carrying a runtime count, and the
        // index stores fully-formatted strings — so it cannot be
        // indexed at all without inventing an argument. Do not
        // "fix" this exclusion by passing a fake count.
        "space_override.dormant.label",
    ]

    @Test("every index key has a rendering call site")
    func indexKeysHaveRenderingCallSites() throws {
        let indexKeys = try lKeys(in: indexSource())
        // The regex and the file path both went stale if this
        // fires — an empty key set would vacuously pass below.
        #expect(!indexKeys.isEmpty)

        var rendered = Set<String>()
        for file in try swiftSources(under: settingsDir)
        where file.lastPathComponent != "SidebarSearch.swift" {
            rendered.formUnion(
                try lKeys(
                    in: String(
                        contentsOf: file,
                        encoding: .utf8
                    )
                )
            )
        }
        for key in indexKeys {
            #expect(
                rendered.contains(key),
                "stale search index key: \(key)"
            )
        }
    }

    /// The reverse direction: every literal
    /// `SettingsSection(L("key", ...))` header under Settings/
    /// **and every `DisclosureGroup` label** must be indexed or
    /// consciously excluded, so a new section can't ship
    /// silently unsearchable. Mode names route through
    /// `LayoutMode.displayName`, so its `LayoutModeGlyph.swift`
    /// keys count as indexed.
    ///
    /// Disclosures were added to this scan in #277. They were
    /// the guard's structural blind spot: it matched only
    /// `SettingsSection(`, so the three "Advanced" drawers —
    /// including General's, which holds the config path and
    /// "Edit init.lua directly" — were unsearchable and *no
    /// test could fail*. A drawer is exactly what a user
    /// searches for, being the content they cannot see.
    @Test("every rendered section header is indexed")
    func renderedHeadersAreIndexed() throws {
        var indexed = try lKeys(in: indexSource())
        let glyphFile = settingsDir.appendingPathComponent(
            "Components/Common/LayoutModeGlyph.swift"
        )
        indexed.formUnion(
            try lKeys(
                in: String(
                    contentsOf: glyphFile,
                    encoding: .utf8
                )
            )
        )

        var headers = Set<String>()
        for file in try swiftSources(under: settingsDir) {
            headers.formUnion(
                try sectionHeaderKeys(
                    in: String(
                        contentsOf: file,
                        encoding: .utf8
                    )
                )
            )
        }
        #expect(!headers.isEmpty)

        // Drawers are section headers as far as a *searching*
        // user is concerned: a drawer is collapsed, so its
        // contents are exactly what they cannot find by
        // scanning. Discovered, not hand-listed — a list would
        // be fail-OPEN for the case this guard exists to catch,
        // since a brand-new drawer absent from both the list and
        // the index would never be examined at all.
        var drawers = Set<String>()
        var unresolved: [String] = []
        for file in try swiftSources(under: settingsDir) {
            let found = disclosureTitleKeys(
                in: try String(contentsOf: file, encoding: .utf8)
            )
            drawers.formUnion(found.keys)
            unresolved += found.unresolved.map {
                "\(file.lastPathComponent): \($0)"
            }
        }
        // An unresolvable site must be loud, never skipped —
        // skipping is how a scan silently becomes a no-op.
        let stuck = unresolved.joined(separator: ", ")
        #expect(
            unresolved.isEmpty,
            Comment(
                rawValue:
                    "DisclosureGroup label(s) the walker could "
                    + "not resolve: " + stuck
            )
        )
        // 9 sites, 8 keys: `bars.advanced_colors` renders twice.
        #expect(drawers.count == 8)
        headers.formUnion(drawers)
        for key in headers where !unindexed.contains(key) {
            #expect(
                indexed.contains(key),
                "unindexed section header: \(key)"
            )
        }
    }

    /// Title keys of every `DisclosureGroup`, by walking
    /// delimiters rather than matching a flat regex.
    ///
    /// A regex cannot do this: the label may lead the
    /// initializer (`DisclosureGroup(L("gaps.per_edge", …), …)`)
    /// or trail the body (`… { body } label: { … }`), and
    /// "the next `label:` after `DisclosureGroup`" picks the
    /// wrong key — `GeneralSection`'s drawer body contains a
    /// `Button { … } label: { Label(L("…edit_lua", …))`, so the
    /// naive anchor selects a control inside the drawer.
    ///
    /// Walking the actual `(…)` and `{…}` nesting resolves every
    /// site in the tree. A site it *cannot* resolve (a label
    /// hoisted into a computed property, say) is returned as
    /// unresolved so the caller can fail loudly — turning an
    /// exotic new shape into a one-line decision instead of a
    /// silent gap.
    private func disclosureTitleKeys(
        in source: String
    ) -> (keys: Set<String>, unresolved: [String]) {
        let text = Array(stripComments(source))
        var keys = Set<String>()
        var unresolved: [String] = []
        let needle = Array("DisclosureGroup")
        var i = 0
        while i + needle.count <= text.count {
            guard Array(text[i..<(i + needle.count)]) == needle
            else {
                i += 1
                continue
            }
            var cursor = i + needle.count
            guard
                let args = balanced(
                    text,
                    from: &cursor,
                    open: "(",
                    close: ")"
                )
            else {
                unresolved.append("unbalanced args at \(i)")
                i += needle.count
                continue
            }
            // Leading-label form: the title is an argument.
            if let key = firstKey(
                in: args,
                pattern: #"L\(\s*"([a-z0-9_.]+)""#
            ) {
                keys.insert(key)
                i = cursor
                continue
            }
            // Trailing-label form: body first, then `label:`.
            guard
                balanced(
                    text,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ) != nil,
                skipLiteral("label:", text, from: &cursor),
                let label = balanced(
                    text,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ),
                let key = firstKey(
                    in: label,
                    pattern: #"L\(\s*"([a-z0-9_.]+)""#
                )
            else {
                unresolved.append("unresolved label at \(i)")
                i += needle.count
                continue
            }
            keys.insert(key)
            i = cursor
        }
        return (keys, unresolved)
    }

    /// Consumes whitespace then a balanced `open`…`close` run,
    /// returning its interior. String literals are skipped so a
    /// brace or paren inside one cannot unbalance the walk.
    private func balanced(
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

    /// Consumes whitespace then `literal`, if present.
    private func skipLiteral(
        _ literal: String,
        _ text: [Character],
        from cursor: inout Int
    ) -> Bool {
        var i = cursor
        while i < text.count, text[i].isWhitespace { i += 1 }
        let wanted = Array(literal)
        guard
            i + wanted.count <= text.count,
            Array(text[i..<(i + wanted.count)]) == wanted
        else { return false }
        cursor = i + wanted.count
        return true
    }

    /// The FIRST match in document order. Deliberately not
    /// `keys(in:pattern:).first` — that returns a `Set`, whose
    /// `first` is arbitrary order, which silently picks a random
    /// key out of the slice while looking correct.
    private func firstKey(
        in source: String,
        pattern: String
    ) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            ),
            let range = Range(match.range(at: 1), in: source)
        else { return nil }
        return String(source[range])
    }

    private func indexSource() throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(
                "SidebarSearch.swift"
            ),
            encoding: .utf8
        )
    }

    /// Every `L("key", ...)` literal in a source string; the
    /// pattern tolerates the 79-char style's line break
    /// between `L(` and the key. Comments are stripped first,
    /// so a doc-comment example can't masquerade as a
    /// rendering call site (the phantom-key hazard that made
    /// `extract-keys` comment-aware).
    private func lKeys(in source: String) throws -> Set<String> {
        try keys(
            in: stripComments(source),
            pattern: #"L\(\s*"([a-z0-9_.]+)""#
        )
    }

    /// Literal first-argument keys of `SettingsSection(L(...))`
    /// call sites. Computed titles (a variable first argument)
    /// are invisible to this scan by construction.
    private func sectionHeaderKeys(
        in source: String
    ) throws -> Set<String> {
        try keys(
            in: stripComments(source),
            pattern:
                #"SettingsSection\(\s*L\(\s*"([a-z0-9_.]+)""#
        )
    }

    private func keys(
        in source: String,
        pattern: String
    ) throws -> Set<String> {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        var keys = Set<String>()
        regex.enumerateMatches(
            in: source,
            range: range
        ) { match, _, _ in
            guard
                let match,
                let keyRange = Range(
                    match.range(at: 1),
                    in: source
                )
            else { return }
            keys.insert(String(source[keyRange]))
        }
        return keys
    }

    /// Cuts each line at its first `//` — adequate for this
    /// repo (no `/* */` convention), and string literals never
    /// carry `//` before an `L(` key on the same line.
    private func stripComments(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let slash = line.range(of: "//") {
                    return line[..<slash.lowerBound]
                }
                return line
            }
            .joined(separator: "\n")
    }

    private func swiftSources(
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
}
