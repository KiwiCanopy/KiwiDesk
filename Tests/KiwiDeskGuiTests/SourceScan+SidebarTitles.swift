import Foundation

// The sidebar destinations' `L(key, english)` pairs, read from
// `SettingsDestination.swift` rather than re-listed in a suite —
// a hand-listed key set is one more place to forget a new
// destination.
//
// Here rather than in one of its two callers for the reason this
// family exists (AGENTS.md §5): `SidebarLabelWidthTests` measures
// the values and `SidebarCrossReferenceTests` matches against
// them, so a copy loosened in one and not the other would leave
// one guard reasoning about a different set of destinations than
// the other while both stay green.
extension SourceScan {
    struct SidebarTitle {
        let key: String
        let english: String
    }

    /// Every `L("sidebar.…", "English")` pair in
    /// `SettingsDestination.swift`, in source order.
    ///
    /// Comments are stripped first: a doc-comment example naming
    /// an `L("sidebar.…")` would otherwise inflate the set and
    /// mask a title that really is missing one.
    ///
    /// The pattern tolerates the call being WRAPPED, because
    /// `swift format` wraps one the moment the key and English
    /// cross 79 columns — `sidebar.advanced_colors` arrived that
    /// way with #678 Phase 3 and red the count pin, which is the
    /// scan failing shut rather than quietly measuring one label
    /// fewer. Both literals must still be literals; anything the
    /// extractor cannot read is not a key either
    /// (`docs/translating.md`, "Extraction limitations").
    static func sidebarTitles(root: URL) throws -> [SidebarTitle] {
        let source = stripComments(
            try String(
                contentsOf:
                    root
                    .appendingPathComponent("Sources")
                    .appendingPathComponent("KiwiDesk")
                    .appendingPathComponent("Settings")
                    .appendingPathComponent(
                        "SettingsDestination.swift"
                    ),
                encoding: .utf8
            )
        )
        return allMatchGroups(
            in: source,
            pattern:
                #"L\(\s*"(sidebar\.[a-z_]+)",\s*"([^"]+)"\s*\)"#,
            groups: [1, 2]
        )
        .compactMap { found in
            guard let key = found[1], let english = found[2]
            else { return nil }
            return SidebarTitle(key: key, english: english)
        }
    }
}
