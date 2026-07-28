import KiwiDeskCore

/// The Settings control catalog (#277): every searchable thing,
/// declared once as a `SettingsControl` / `SettingsDrawer` value
/// that the render site consumes and the search index enumerates
/// by reflection (`SettingsControlIndex`). Replaced the
/// hand-maintained `SidebarSearchIndex` entry list.
///
/// The declarations themselves live one file per sidebar group —
/// `SettingsCatalog+ThisProfile.swift` and
/// `SettingsCatalog+WholeApp.swift` — leaving this file the
/// aggregation and the enumeration. Every `SettingsCatalog+*`
/// slice counts as catalog to the guards, so a further slice
/// needs no allow-listing — the `+` is load-bearing, and
/// `SettingsCatalogFiles` records why.
///
/// `Mirror` yields stored properties in declaration order, so the
/// index order is deterministic; keeping it *matching* the view's
/// visual order is a discipline, not a structural guarantee
/// (a section reordered in its body without reordering its struct
/// desyncs them). The blast radius is bounded: one row per
/// destination means order only breaks ties among several matches
/// in one destination.
/// Property names are the tokens the site guards scan for
/// (`SettingsCatalogSiteTests`), so they must be unique across
/// the whole catalog and distinctive enough not to collide with
/// unrelated identifiers (`.title` or `.appBarStyle` would match
/// half the tree; `.appBarStyleCard` matches only its reference).
///
/// Known limit, recorded since tier 1: the per-Space "Overrides…"
/// popover stays uncataloged — it opens from a row button rather
/// than a destination, so a reveal has nowhere to send the user
/// (`docs/accepted-limitations.md`). Its rows also mirror
/// `layout_params.*` labels the Layout Defaults tabs carry.
///
/// The catalog's one instance per destination, and the index
/// enumeration the search matcher reads.
enum SettingsCatalog {
    static let spaces = SpacesControls()
    static let layoutDefaults = LayoutDefaultsControls()
    static let monitors = MonitorsControls()
    static let appearance = AppearanceControls()
    static let bars = BarsControls()
    static let behavior = BehaviorControls()
    static let profiles = ProfilesControls()
    static let shortcuts = ShortcutsControls()
    static let appRules = AppRulesControls()
    static let general = GeneralControls()

    /// The render sites' access to a mode tab's descriptor — the
    /// same factory the index uses, so the two cannot drift.
    static func layoutMode(_ mode: LayoutMode) -> SettingsControl {
        .layoutMode(mode)
    }

    /// The declaration struct behind a destination — the one
    /// enumerated for its index and walked by the catalog guards.
    /// A single home for the destination→container mapping, so
    /// `entries(of:)` and the strict-enumeration guard cannot
    /// disagree about which struct a destination reflects.
    static func container(
        of destination: SettingsDestination
    ) -> Any {
        switch destination {
        case .spaces: return spaces
        case .layoutDefaults: return layoutDefaults
        case .monitors: return monitors
        case .appearance: return appearance
        case .bars: return bars
        case .behavior: return behavior
        case .profiles: return profiles
        case .shortcuts: return shortcuts
        case .appRules: return appRules
        case .general: return general
        }
    }

    /// Everything searchable inside `destination`, in render
    /// order. Each tab names its own mode, so a hit selects
    /// that tab (#277 sub-problem 2).
    ///
    /// Layout Defaults appends its mode tabs after the reflected
    /// entries: their text is `LayoutMode.displayName` (not a
    /// catalog literal), so they come from the `placementTabs`
    /// factory rather than a stored declaration.
    static func entries(
        of destination: SettingsDestination
    ) -> [SettingsIndexEntry] {
        let reflected = SettingsControlIndex.entries(
            in: container(of: destination)
        )
        guard destination == .layoutDefaults else { return reflected }
        return reflected
            + LayoutMode.placementTabs.map {
                SettingsIndexEntry(
                    control: .layoutMode($0),
                    parent: nil,
                    propertyPath: []
                )
            }
    }
}
