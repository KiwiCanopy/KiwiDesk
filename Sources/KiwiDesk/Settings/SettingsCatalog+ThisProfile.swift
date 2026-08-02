import KiwiDeskCore

// The declaration structs behind the sidebar's **This Profile**
// group (`SettingsDestination.thisProfile`): Spaces, Layout
// Defaults, Monitors, Appearance, Bars, Behavior. Split from
// `SettingsCatalog.swift` on the seam the sidebar already
// draws, so a destination's declarations sit where its
// neighbours do. The aggregation and the enumeration stay in
// `SettingsCatalog.swift`; the authoring rules are in its
// header, and the catalog guards treat every
// `SettingsCatalog+*` slice as catalog, not as a render site —
// the `+` is load-bearing, see `SettingsCatalogFiles`.

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
    /// The two bar cards, one page (turn 7a of the redesign —
    /// the #293 App Bar / Space Bar switch is gone). The card
    /// titles keep the old switch chips' `bars.switch.*` keys:
    /// the English is unchanged ("Space Bar" / "App Bar"), so
    /// re-keying would only throw away eleven translations.
    ///
    /// Space Bar leads, matching everywhere else it does — the
    /// omnipresent bar, and the first card on the page — so a
    /// bare "bar" query (which matches both under the one-row
    /// cap) surfaces the leading bar, not App Bar.
    let spaceBarCard = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar"
    )
    /// One "Style" drawer per card, co-rendered on the one page,
    /// so each carries its own instance id — the twice-mounted
    /// shape (#277) that a shared declaration would make
    /// `scrollTo`-undefined.
    let spaceBarStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "space_bar"
    )
    let appBarCard = SettingsControl(
        "bars.switch.app_bar",
        "App Bar"
    )
    let appBarStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "app_bar"
    )
    /// The two "Show it in" rows, titled by their layout's name
    /// (the keys `LayoutMode.displayName` authors). Distinct
    /// keys, so no instance tag is needed.
    let monocleShowIn = SettingsControl(
        "layout.monocle.name",
        "Monocle"
    )
    let scrollingShowIn = SettingsControl(
        "layout.scrolling.name",
        "Scrolling"
    )
    /// The interim colour cards — the census places bar colours
    /// in Advanced Colours, which the Colours phase renders;
    /// until then these keep the only colour GUI alive.
    /// "App Bar colors", not "Global …" (ui-designer
    /// 2026-07-28): "Global" is KiwiDesk's word for the
    /// config-vs-override axis (the Profiles system).
    let spaceBarColorsCard = SettingsControl(
        "space_bar.colors.title",
        "Space Bar colors"
    )
    /// The two Advanced-colors drawers co-render on the one page
    /// now, so the old shared surface-free declaration (whose
    /// justification was the mutual exclusion of the switch)
    /// splits into per-instance ids, like the Style drawers.
    let spaceBarAdvancedColors = SettingsDrawer(
        "bars.advanced_colors",
        "Advanced colors",
        instance: "space_bar"
    )
    let appBarColorsCard = SettingsControl(
        "app_bar.global_colors.title",
        "App Bar colors"
    )
    let appBarAdvancedColors = SettingsDrawer(
        "bars.advanced_colors",
        "Advanced colors",
        instance: "app_bar"
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
