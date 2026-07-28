import KiwiDeskCore

/// The Settings control catalog (#277): every searchable thing,
/// declared once as a `SettingsControl` / `SettingsDrawer` value
/// that the render site consumes and the search index enumerates
/// by reflection (`SettingsControlIndex`). Replaced the
/// hand-maintained `SidebarSearchIndex` entry list.
///
/// `Mirror` yields stored properties in declaration order, so the
/// index order is deterministic; keeping it *matching* the view's
/// visual order is a discipline, not a structural guarantee
/// (a section reordered in its body without reordering this struct
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

struct SpacesControls: Sendable {
    let spacesCard = SettingsControl("spaces.title", "Spaces")
}

struct LayoutDefaultsControls: Sendable {
    /// The min-size card sits above the strip and feeds every
    /// mode, so it is surface-free; the mode tabs are appended
    /// from `LayoutMode.placementTabs` in `entries(of:)`.
    let minWindowSize = SettingsControl(
        "layout_defaults.min_window_size",
        "Minimum window size"
    )
}

struct MonitorsControls: Sendable {
    let spacePlacement = SettingsControl(
        "monitors.space_placement",
        "Space placement"
    )
    let orphanPins = SettingsControl(
        "monitors.orphan_pins.title",
        "Pinned to disconnected monitors"
    )
    let monitorFingerprints = SettingsDrawer(
        "monitors.advanced.title",
        "Monitor fingerprints"
    )
}

struct GapEdgeControls: Sendable {
    let edgeTop = SettingsControl("gaps.top", "Top")
    let edgeBottom = SettingsControl("gaps.bottom", "Bottom")
    let edgeLeft = SettingsControl("gaps.left", "Left")
    let edgeRight = SettingsControl("gaps.right", "Right")
}

struct GapAxisControls: Sendable {
    let axisHorizontal = SettingsControl(
        "gaps.horizontal",
        "Horizontal"
    )
    let axisVertical = SettingsControl("gaps.vertical", "Vertical")
}

struct AppearanceControls: Sendable {
    let paletteShelf = SettingsControl(
        "palettes.title",
        "Color palette"
    )
    let gapsCard = SettingsControl("gaps.title", "Gaps")
    let gapsPerEdge = SettingsDrawer(
        "gaps.per_edge",
        "Per-edge…",
        children: GapEdgeControls()
    )
    let gapsPerAxis = SettingsDrawer(
        "gaps.per_axis",
        "Per-axis…",
        children: GapAxisControls()
    )
    let dragCard = SettingsControl("drag.title", "Drag & drop")
    let dragGhost = SettingsControl("drag.ghost", "Ghost")
    let dragDropZone = SettingsControl(
        "drag.drop_zone",
        "Drop zone"
    )
    let focusBorder = SettingsControl(
        "border.title",
        "Focus border"
    )
    let stickyWindows = SettingsControl(
        "sticky.title",
        "Sticky windows"
    )
}

struct BarsControls: Sendable {
    /// The App Bar / Space Bar switch chips, indexed so the bare
    /// bar name is findable — searching "App Bar" selects that
    /// editor and flashes its chip. Reuses the chips' existing
    /// `bars.switch.*` label keys (same English), so the chip and
    /// the search entry name the bar with one string. Declared
    /// before the sections so a bare bar-name query lands on the
    /// switch rather than a section below it. `BarEditorPicker`
    /// carries these ids.
    ///
    /// Space Bar leads, matching everywhere else it does — the
    /// default editor, the picker order, the omnipresent bar — so
    /// a bare "bar" query (which matches both under the one-row
    /// cap) surfaces the leading bar, not App Bar.
    let spaceBarSwitch = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar",
        surface: .bar(.spaceBar)
    )
    let appBarSwitch = SettingsControl(
        "bars.switch.app_bar",
        "App Bar",
        surface: .bar(.appBar)
    )
    /// "App Bar style"/"App Bar colors", not "Global …"
    /// (ui-designer 2026-07-28): "Global" is KiwiDesk's word for
    /// the config-vs-override axis (the Profiles system), so
    /// reusing it here for bar-wide-vs-per-layout collides with
    /// established vocabulary and reads ambiguously in isolation
    /// (a search hit or screenshot has no switch chip in view).
    /// The global-vs-override distinction is already carried by
    /// structure — the per-layout "Overrides" drawers nested under
    /// each named layout section — so the word is redundant here.
    /// Mirrors the Space Bar's own `"<bar> style"` pattern, whose
    /// key is likewise `…global_style…` but whose display was
    /// already written bar-named.
    let appBarStyleCard = SettingsControl(
        "app_bar.global_style.title",
        "App Bar style",
        surface: .bar(.appBar)
    )
    let appBarColorsCard = SettingsControl(
        "app_bar.global_colors.title",
        "App Bar colors",
        surface: .bar(.appBar)
    )
    /// Renders inside BOTH colour groups, so it stays
    /// surface-free on purpose: pinning it to one side would
    /// yank a user reading the other bar across the switch to
    /// an identically-named drawer. Both drawers mount this one
    /// declaration — only one editor renders at a time, so the
    /// shared id is never ambiguous, and the reveal lands on
    /// whichever side is already showing.
    let advancedColors = SettingsDrawer(
        "bars.advanced_colors",
        "Advanced colors"
    )
    let spaceBarStyleCard = SettingsControl(
        "space_bar.global_style.title",
        "Space Bar style",
        surface: .bar(.spaceBar)
    )
    let spaceBarColorsCard = SettingsControl(
        "space_bar.colors.title",
        "Space Bar colors",
        surface: .bar(.spaceBar)
    )
    /// One declaration per co-mounted `LayoutAppBarGroup` mount
    /// (Monocle and Scrolling render together on the App Bar
    /// side), so each drawer carries its own id — the
    /// twice-mounted shape the part-1 site guard was blind to,
    /// now impossible to conflate by construction.
    let monocleBarOverrides = SettingsDrawer(
        "app_bar.layout.overrides",
        "Overrides",
        surface: .bar(.appBar),
        instance: "monocle"
    )
    let scrollingBarOverrides = SettingsDrawer(
        "app_bar.layout.overrides",
        "Overrides",
        surface: .bar(.appBar),
        instance: "scrolling"
    )
}

struct BehaviorControls: Sendable {
    let mouseCard = SettingsControl(
        "behavior.mouse.title",
        "Mouse"
    )
    let animationsCard = SettingsControl(
        "behavior.animations.title",
        "Animations"
    )
    let quitCard = SettingsControl("behavior.quit.title", "On quit")
}

struct ProfilesControls: Sendable {
    let savedProfiles = SettingsControl(
        "profiles.saved.title",
        "Saved profiles"
    )
    let presetsCard = SettingsControl("presets.title", "Presets")
    let nativeSpaces = SettingsControl(
        "native_spaces.title",
        "Profiles per macOS Space"
    )
}

struct ShortcutsControls: Sendable {
    let switchModes = SettingsControl(
        "shortcuts.section.switch_modes",
        "Switch modes"
    )
    let focusKeys = SettingsControl(
        "shortcuts.section.focus",
        "Focus"
    )
    let moveWindows = SettingsControl(
        "shortcuts.section.move_windows",
        "Move windows"
    )
    let sizeFloat = SettingsControl(
        "shortcuts.section.size_float",
        "Size & float"
    )
    let openApplications = SettingsControl(
        "shortcuts.section.open_applications",
        "Open applications"
    )
    let generalKeys = SettingsControl(
        "shortcuts.section.general",
        "General"
    )
    let inactiveShortcuts = SettingsControl(
        "shortcuts.section.inactive",
        "Inactive shortcuts"
    )
    let profileShortcuts = SettingsControl(
        "shortcuts.override.title",
        "Profile shortcuts"
    )
    let luaBindings = SettingsDrawer(
        "shortcuts.advanced.title",
        "Lua bindings"
    )
}

struct AppRulesControls: Sendable {
    let rulesPerApp = SettingsControl(
        "app_rules.section.title",
        "Rules per app"
    )
}

struct GeneralControls: Sendable {
    let loginItemCard = SettingsControl(
        "general.login_item.title",
        "Open KiwiDesk at Login"
    )
    let languageCard = SettingsControl(
        "general.language.title",
        "Language"
    )
    let aboutCard = SettingsControl(
        "general.about.title",
        "About"
    )
    let generalAdvanced = SettingsDrawer(
        "general.advanced.title",
        "Advanced"
    )
}

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
