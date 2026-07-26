import Foundation
import Testing

/// The search index is a second mirror of the subsection-title
/// list (.claude/rules/parity-tests.md): the titles live once
/// at their `SettingsSection(...)` call sites and once in
/// `SidebarSearchIndex.entries(of:)`. Source-scanning
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
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// Is this one of the index's own files, whose `L()` tuples
    /// ARE the index rather than a rendering call site?
    ///
    /// A prefix rule, not a hand-listed set: the index is going to
    /// be split further as the per-control catalog grows
    /// (`SidebarSearchIndex+Controls.swift`), and a grown set
    /// fails **open** in a guard whose whole design is fail-shut —
    /// a new index file absent from the set contributes no keys to
    /// the forward check while landing on the *render* side, where
    /// its own tuples vouch for themselves. `SidebarSearchRow` and
    /// `SidebarSearchField` are presentation and stay on the
    /// render side.
    private func isIndexFile(_ name: String) -> Bool {
        name == "SidebarSearch.swift"
            || name.hasPrefix("SidebarSearchIndex")
    }

    /// Index keys whose anchor is real but invisible to a source
    /// scan, because the title reaches `SettingsSection` through a
    /// computed property instead of a literal `L(...)` argument.
    /// Fail-shut: a new index key is either anchored at a literal
    /// site or listed here with its reason.
    private let computedAnchors: Set<String> = [
        // `DragVisualsEditor`'s `ghostLabel` / `dropZoneLabel` are
        // computed, then passed positionally into the shared
        // `column(title:…)` helper. `SettingsSection` anchors
        // itself from whatever string it is handed, so these two
        // DO scroll and flash — only the scan is blind to them.
        "drag.ghost",
        "drag.drop_zone",
    ]

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
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !isIndexFile(file.lastPathComponent) {
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

    /// The direction that was missing, and whose absence shipped
    /// six broken entries (#277 QA): an index key must name a
    /// label some view **anchors itself with**, not merely a
    /// string that exists somewhere under `Settings/`.
    ///
    /// `indexKeysHaveRenderingCallSites` above accepts any `L()`
    /// call anywhere in the tree, so all six of tier 1's drawer
    /// entries passed it while `proxy.scrollTo` was a silent
    /// no-op and nothing flashed — searching "Per-edge…" opened
    /// Appearance and sat at the top of the pane. The suite's own
    /// new-suite twin could not catch it either: it compared the
    /// anchors the matcher produces against the index they were
    /// copied from, so it was tautological.
    ///
    /// Anchorable means exactly three things:
    /// `SettingsSection(L(...))`, which anchors itself from the
    /// title it is handed; `.searchAnchor(L(...))`, the opt-in a
    /// bare `DisclosureGroup` needs; and `LayoutMode.displayName`,
    /// whose tuples the per-mode editors pass to
    /// `SettingsSection`.
    @Test("every index key is anchored by some view")
    func indexKeysAreAnchored() throws {
        let indexKeys = try lKeys(in: indexSource())
        // 38 today. Pinned, not just non-empty: the file set is
        // now discovered by prefix, so a split that silently
        // dropped a file would shrink this rather than emptying
        // it, and a shrunken set still passes every `contains`
        // check below.
        #expect(indexKeys.count == 38)

        var anchorable = Set<String>()
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !isIndexFile(file.lastPathComponent) {
            let source = try String(
                contentsOf: file,
                encoding: .utf8
            )
            anchorable.formUnion(
                try sectionHeaderKeys(in: source)
            )
            anchorable.formUnion(
                try searchAnchorKeys(in: source)
            )
            if file.lastPathComponent
                == "LayoutModeGlyph.swift"
            {
                anchorable.formUnion(try lKeys(in: source))
            }
        }
        #expect(!anchorable.isEmpty)

        for key in indexKeys where !computedAnchors.contains(key) {
            #expect(
                anchorable.contains(key),
                Comment(
                    rawValue:
                        "indexed but unanchored — a reveal on "
                        + "this key scrolls nowhere and flashes "
                        + "nothing: \(key)"
                )
            )
        }
        // The exemptions must stay real. A key that stops being
        // indexed, or gains a literal anchor, has to leave the
        // set rather than sit there vouching for nothing.
        for key in computedAnchors {
            #expect(
                indexKeys.contains(key),
                "stale computedAnchors entry: \(key)"
            )
            #expect(
                !anchorable.contains(key),
                Comment(
                    rawValue:
                        "\(key) now has a literal anchor; drop "
                        + "it from computedAnchors"
                )
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
        for file in try SourceScan.swiftSources(under: settingsDir) {
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
        for file in try SourceScan.swiftSources(under: settingsDir) {
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
        let text = Array(SourceScan.stripComments(source))
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
                let args = SourceScan.balanced(
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
                SourceScan.balanced(
                    text,
                    from: &cursor,
                    open: "{",
                    close: "}"
                ) != nil,
                SourceScan.skipLiteral(
                    "label:",
                    text,
                    from: &cursor
                ),
                let label = SourceScan.balanced(
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
        try SourceScan.swiftSources(under: settingsDir)
            .filter { isIndexFile($0.lastPathComponent) }
            .sorted { $0.path < $1.path }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    /// Literal keys passed to `.searchAnchor(L(...))` — the
    /// anchor a `DisclosureGroup` label must opt into, since only
    /// `SettingsSection` anchors itself.
    private func searchAnchorKeys(
        in source: String
    ) throws -> Set<String> {
        try keys(
            in: SourceScan.stripComments(source),
            pattern: #"\.searchAnchor\(\s*L\(\s*"([a-z0-9_.]+)""#
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
            in: SourceScan.stripComments(source),
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
            in: SourceScan.stripComments(source),
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
}
