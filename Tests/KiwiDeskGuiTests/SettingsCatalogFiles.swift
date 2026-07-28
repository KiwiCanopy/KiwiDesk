import Foundation

/// Which files under `Sources/KiwiDesk/Settings` ARE the catalog
/// — everywhere else is a render site. Four sweeps ask, across
/// three suites (`SettingsCatalogSiteTests`,
/// `SettingsCatalogArgumentTests`,
/// `SettingsAnchorPrimitiveTests`), so the prefix literal lives
/// here once: narrow it in one copy and not the other and the
/// wider copy silently exempts a file from a fail-open guard.
///
/// **The `+` is load-bearing, and it was not always here.** A
/// bare `hasPrefix("SettingsCatalog")` exempts any file merely
/// *named* like the catalog — an architect review proved it by
/// dropping a `SettingsCatalogProbe.swift` view that constructed
/// a descriptor inline, rendered it and anchored it: every guard
/// passed, and it was exactly the rendered-but-unsearchable case
/// the one-list design exists to close. Renamed `ProbeCard.swift`
/// it failed instantly. Matching the repo's own splitting
/// convention (`SettingsModel+*`, `SourceScan+*`) keeps the
/// payoff — a new `SettingsCatalog+Foo.swift` slice still needs
/// no allow-listing — while a view cannot claim the exemption by
/// picking a name.
enum SettingsCatalogFiles {
    /// The declaration files: where `SettingsControl(` /
    /// `SettingsDrawer(` literals legitimately live.
    static func isDeclarationFile(_ name: String) -> Bool {
        name.hasPrefix("SettingsCatalog+")
            || name == "SettingsCatalog.swift"
    }

    /// The declaration files plus `SettingsControl.swift`, which
    /// defines the types and the enumerator but declares no
    /// control. Excluded from render-site sweeps, since a
    /// declaration is not a reference to itself.
    static func isCatalogFile(_ name: String) -> Bool {
        isDeclarationFile(name) || name == "SettingsControl.swift"
    }
}
