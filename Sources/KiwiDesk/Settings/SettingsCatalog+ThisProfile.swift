import KiwiDeskCore

// The declaration structs behind the sidebar's **This Profile**
// group (`SettingsDestination.thisProfile`): Spaces, Layout
// Defaults, Monitors, Appearance, Bars, Behavior. Split from
// `SettingsCatalog.swift` on the seam the sidebar already
// draws, so a destination's declarations sit where its
// neighbours do. The aggregation and the enumeration stay in
// `SettingsCatalog.swift`; the authoring rules are in its
// header, and `SettingsCatalogSiteTests` treats every
// `SettingsCatalog*` file as catalog, not as a render site.

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
