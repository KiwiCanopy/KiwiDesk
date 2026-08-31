import KiwiDeskCore

/// Settings control catalog and search index definitions (#277).
///
/// Declarations are grouped in `SettingsCatalog+ThisProfile.swift`
/// and `SettingsCatalog+WholeApp.swift` (`SettingsCatalogFiles`,
/// `docs/accepted-limitations.md`). Property names are the tokens
/// the site guards scan for (`SettingsCatalogSiteTests`): unique
/// across the catalog, and distinctive enough not to collide with
/// unrelated identifiers. `Mirror` yields declaration order, so
/// keeping it matching the view's visual order is a discipline,
/// not a structural guarantee.
enum SettingsCatalog {
    static let spaces = SpacesControls()
    static let layoutDefaults = LayoutDefaultsControls()
    static let monitors = MonitorsControls()
    static let colors = ColorsControls()
    static let advancedColors = AdvancedColorsControls()
    static let gapsAndBorders = GapsAndBordersControls()
    static let bars = BarsControls()
    static let behavior = BehaviorControls()
    static let profiles = ProfilesControls()
    static let shortcuts = ShortcutsControls()
    static let appRules = AppRulesControls()
    static let general = GeneralControls()

    /// Descriptor for a layout mode tab in settings.
    static func layoutMode(_ mode: LayoutMode) -> SettingsControl {
        .layoutMode(mode)
    }

    /// Declaration struct for a given settings destination.
    static func container(
        of destination: SettingsDestination
    ) -> Any {
        switch destination {
        case .spaces: return spaces
        case .layoutDefaults: return layoutDefaults
        case .monitors: return monitors
        case .colors: return colors
        case .advancedColors: return advancedColors
        case .gapsAndBorders: return gapsAndBorders
        case .bars: return bars
        case .behavior: return behavior
        case .profiles: return profiles
        case .shortcuts: return shortcuts
        case .appRules: return appRules
        case .general: return general
        }
    }

    /// Returns searchable index entries for destination
    /// (#277, `placementTabs`).
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
