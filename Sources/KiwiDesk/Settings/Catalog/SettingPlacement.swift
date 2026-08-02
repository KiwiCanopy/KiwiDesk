/// The placement vocabulary of the settings catalog (#678,
/// spec 4f). Every setting KiwiDesk has is one `SettingKey`
/// case, and each case resolves to its placement and text
/// through exhaustive switches — an unplaced setting is a
/// compile error, not a bug report. During the coexistence
/// phase (old GUI still renders) the catalog is the census the
/// 4f guards hold against the model and the locale catalogs;
/// rendering from it starts with the Bars area (Phase 2).

/// The two Settings modes, in the shipped (site-slider)
/// vocabulary: user-facing "Simple" / "Nerd". The design doc's
/// "Easy/Advanced" is spec-internal shorthand and never appears
/// in code or copy; the word "mode" itself stays reserved for
/// this pair and for layout modes.
enum SettingsMode: CaseIterable, Hashable {
    case simple
    case nerd
}

/// A Home-level area card in the redesigned Settings window.
enum SettingsArea: CaseIterable, Hashable {
    case gapsAndBorders
    case layoutDefaults
    case shortcuts
    case coloursAndMotion
    case bars
    case advancedColours
    case spacesAndLayouts
    case behaviour
    case monitors
    case profiles
    case appRules
    case general

    /// Nerd-only areas exist only while Nerd mode is on; a
    /// card is nerd-only when its area is — never per-row.
    /// Simple-mode areas render in both modes (Nerd adds
    /// surface, never expands it).
    var isNerdOnly: Bool {
        switch self {
        case .layoutDefaults, .advancedColours, .behaviour,
            .monitors:
            return true
        case .gapsAndBorders, .shortcuts, .coloursAndMotion,
            .bars, .spacesAndLayouts, .profiles, .appRules,
            .general:
            return false
        }
    }
}

/// A titled card or group within an area.
enum SettingsContainer: CaseIterable, Hashable {
    case about
    case advanced
    case appBar
    case borders
    case bsp
    case dragAndDrop
    case focus
    case focusBorder
    case gaps
    case general
    case generalKeys
    case grid
    case language
    case layers
    case login
    case luaBindings
    case monitorFingerprints
    case monocle
    case motion
    case mouse
    case moveWindows
    case onQuit
    case openApplications
    case palettes
    case perSpaceOverrides
    case pinnedToDisconnectedMonitors
    case profilesPerMacOSSpace
    case rulesPerApp
    case savedProfiles
    case scrolling
    case sizeAndFloat
    case spaceBar
    case spaceList
    case spacePlacement
    case stack
    case stickyWindows
    case track
}

/// How deep a setting sits (decision-log item 12). "Show more"
/// rows and nerd-only cards are different things — never
/// conflate them in copy or code (item 7): `.showMore` is a
/// row-level disclosure; mode depth is
/// `SettingsArea.isNerdOnly`.
enum SettingTier: Hashable {
    /// Visible at rest in its container.
    case atRest
    /// Behind the container's "Show more" disclosure.
    case showMore
    /// Surfaces without disclosure the moment its gate allows.
    case immediate
    /// Reachable only from Lua (`init.lua`), by design.
    case luaOnly
    /// App-internal storage (picker recents) — no surface.
    case internalOnly
    /// Lives outside the Settings window (onboarding wizard).
    case outsideSettings
}

/// How a row is titled: a stable `L()` key, or text the GUI
/// composes at runtime (space names, per-instance keybinding
/// rows, the orientation-swapped slot-size label).
enum SettingLabel: Hashable {
    case key(String)
    case dynamic
}

/// The localized text a row carries — label, optional grey
/// caption, optional `?` help popover. Reuses the live GUI's
/// `L()` keys during coexistence; tiers the GUI never renders
/// (`.luaOnly`, `.internalOnly`, `.outsideSettings`) carry
/// `.none`.
struct SettingRowText: Hashable {
    var label: SettingLabel?
    var captionKey: String?
    var helpKey: String?

    static let none = SettingRowText(
        label: nil,
        captionKey: nil,
        helpKey: nil
    )
    static let dynamic = SettingRowText(
        label: .dynamic,
        captionKey: nil,
        helpKey: nil
    )
    static func text(
        _ labelKey: String,
        caption: String? = nil,
        help: String? = nil
    ) -> SettingRowText {
        SettingRowText(
            label: .key(labelKey),
            captionKey: caption,
            helpKey: help
        )
    }
}

/// Where one setting lives (item 12): area card, container,
/// tier, and — for a row greyed behind another setting — its
/// gate. `area`/`container` are nil exactly for the tiers that
/// have no Settings surface.
struct SettingPlacement: Hashable {
    var area: SettingsArea?
    var container: SettingsContainer?
    var tier: SettingTier
    var gatedBy: SettingKey?

    static let luaOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .luaOnly,
        gatedBy: nil
    )
    static let internalOnly = SettingPlacement(
        area: nil,
        container: nil,
        tier: .internalOnly,
        gatedBy: nil
    )
    static let outsideSettings = SettingPlacement(
        area: nil,
        container: nil,
        tier: .outsideSettings,
        gatedBy: nil
    )
    static func row(
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier,
        gatedBy: SettingKey? = nil
    ) -> SettingPlacement {
        SettingPlacement(
            area: area,
            container: container,
            tier: tier,
            gatedBy: gatedBy
        )
    }
}
