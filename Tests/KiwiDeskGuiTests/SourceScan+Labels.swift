import Foundation

// Localized-label extraction for the search-index guards.
//
// Shared by the search-index parity guards
// (`SidebarSearchParityTests`, `SidebarSearchAnchorSiteTests`):
// pulling `L("key", …)` keys out of Swift source, in the three
// shapes those guards distinguish — any call site, a
// `SettingsSection` title, a `.searchAnchor` opt-in — plus the
// delimiter walker for `DisclosureGroup` labels.
//
// Here rather than duplicated per suite for the reason this whole
// file exists (AGENTS.md §5): two guards now share them, and a
// copy hardened in one place and not the other over-matches,
// swallowing exactly the call sites its guard was meant to catch.
extension SourceScan {
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
    static func disclosureTitleKeys(
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
    static func firstKey(
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

    /// Literal keys passed to `.searchAnchor(L(...))` — the
    /// anchor a `DisclosureGroup` label must opt into, since only
    /// `SettingsSection` anchors itself.
    static func searchAnchorKeys(
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
    static func lKeys(in source: String) throws -> Set<String> {
        try keys(
            in: SourceScan.stripComments(source),
            pattern: #"L\(\s*"([a-z0-9_.]+)""#
        )
    }

    /// Literal first-argument keys of `SettingsSection(L(...))`
    /// call sites. Computed titles (a variable first argument)
    /// are invisible to this scan by construction.
    static func sectionHeaderKeys(
        in source: String
    ) throws -> Set<String> {
        try keys(
            in: SourceScan.stripComments(source),
            pattern:
                #"SettingsSection\(\s*L\(\s*"([a-z0-9_.]+)""#
        )
    }

    /// Every key that tags a view with a scroll id, **with
    /// duplicates** — the two shapes that do so:
    /// `SettingsSection(L(...))`, which anchors itself from the
    /// title it is handed, and an explicit `.searchAnchor(L(...))`.
    ///
    /// An array, not a `Set`, and that is the entire purpose:
    /// counting how many views claim one key is what a set erases,
    /// and the count is the defect (one key on two co-mounted views
    /// makes `scrollTo` undefined and washes both).
    static func anchorSiteKeys(
        in source: String
    ) throws -> [String] {
        let text = stripComments(source)
        return try orderedKeys(
            in: text,
            pattern: #"SettingsSection\(\s*L\(\s*"([a-z0-9_.]+)""#
        )
            + orderedKeys(
                in: text,
                pattern:
                    #"\.searchAnchor\(\s*L\(\s*"([a-z0-9_.]+)""#
            )
    }

    static func keys(
        in source: String,
        pattern: String
    ) throws -> Set<String> {
        Set(try orderedKeys(in: source, pattern: pattern))
    }

    /// Document order, duplicates preserved. `keys` is this
    /// de-duplicated, so the two cannot disagree about what a
    /// pattern matches.
    static func orderedKeys(
        in source: String,
        pattern: String
    ) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        var keys: [String] = []
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
            keys.append(String(source[keyRange]))
        }
        return keys
    }
}
