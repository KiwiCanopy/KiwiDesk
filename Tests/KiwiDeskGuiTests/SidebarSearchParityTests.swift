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

    /// Drawer titles — `DisclosureGroup` labels — which are
    /// section headers as far as a *searching user* is
    /// concerned: a drawer is collapsed, so its contents are
    /// exactly what they cannot see and most need to find.
    ///
    /// Hand-listed, deliberately, after a source scan was tried
    /// and rejected: SwiftUI's label may lead the initializer
    /// (`DisclosureGroup(L(…), isExpanded:)`), trail the body
    /// (`… { body } label: { … }`), or live in a separate
    /// computed property far from the call — so no anchor
    /// reliably picks the title out, and the scan kept selecting
    /// a row from inside the drawer instead. A guard that needs
    /// a growing exclusion list to stay green is worse than an
    /// honest short list. The cost is the usual one: this list
    /// is itself a place to forget, so **add a new drawer here
    /// when you add it to a view**, and note the `unindexed`
    /// set below is what keeps it fail-shut rather than
    /// silently short.
    private let drawerTitles: Set<String> = [
        "general.advanced.title",
        "shortcuts.advanced.title",
        "monitors.advanced.title",
        "bars.advanced_colors",
        "gaps.per_edge",
        "gaps.per_axis",
        "app_bar.layout.overrides",
        "space_override.dormant.label",
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
        // Lives in the per-Space "Overrides…" popover, which is
        // reachable only from a row button, not from a
        // destination — search navigates to destinations, so it
        // has nowhere to send the user.
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
        headers.formUnion(drawerTitles)
        for key in headers where !unindexed.contains(key) {
            #expect(
                indexed.contains(key),
                "unindexed section header: \(key)"
            )
        }
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
