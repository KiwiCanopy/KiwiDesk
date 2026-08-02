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
    /// mask a title that really is missing one. The pattern wants
    /// the call on one line — a wrapped one drops its pair, which
    /// fails SHUT on `SidebarLabelWidthTests`' count pin rather
    /// than silently narrowing either guard.
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
            pattern: #"L\("(sidebar\.[a-z_]+)", "([^"]+)"\)"#,
            groups: [1, 2]
        )
        .compactMap { found in
            guard let key = found[1], let english = found[2]
            else { return nil }
            return SidebarTitle(key: key, english: english)
        }
    }
}
