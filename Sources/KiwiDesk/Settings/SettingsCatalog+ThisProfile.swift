import KiwiDeskCore

// The declaration structs behind the sidebar's **This Profile**
// group (`SettingsDestination.thisProfile`): Spaces, Layout
// Defaults, Monitors, Colors & Motion, Advanced Colors, Gaps &
// Borders, Bars, Behavior. Split from
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
    /// layout, so it is surface-free; the layout tiles are
    /// appended from `LayoutMode.placementTabs` in
    /// `entries(of:)`.
    let minWindowSize = SettingsControl(
        "layout_defaults.min_window_size",
        "Minimum window size"
    )
    /// The live preview and the spaces list are cards a reveal
    /// can land on, so they are declared rather than rendered
    /// with a computed title — a reader searching "preview"
    /// should reach the one that answers "what will this look
    /// like".
    let livePreview = SettingsControl(
        "layout_defaults.live_preview",
        "Live preview"
    )
    let spacesUsing = SettingsControl(
        "layout_defaults.spaces_using",
        "Spaces using this layout"
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

/// Colours & Motion (#678 Phase 3): the palette shelf, the
/// live-colours scene, and the Motion card that moved here whole
/// from Behavior.
struct ColorsControls: Sendable {
    let paletteShelf = SettingsControl(
        "palettes.title",
        "Color palette"
    )
    let currentScene = SettingsControl(
        "colors.scene.title",
        "Current colors"
    )
    let motionCard = SettingsControl(
        "behavior.animations.title",
        "Animations"
    )
    /// Named for what it holds, not "more" or "advanced": this
    /// area's Power-User twin is a whole separate card, and one word
    /// must never mean both a row tier and mode depth.
    let motionMore = SettingsDrawer(
        "motion.more",
        "Per-event and duration"
    )
}

/// Advanced Colours (#678 Phase 3): four groups matching the four
/// things on screen. The two drawers co-render on one page, so
/// each carries its own instance id — the twice-mounted shape
/// (#277) a shared declaration would make `scrollTo`-undefined.
struct AdvancedColorsControls: Sendable {
    /// Each group's title names the SUBSYSTEM plus "colors".
    /// Bare "Space Bar" / "Drag & drop" would collide in search
    /// with the cards that own those things' structure: sidebar
    /// search returns one row per destination, so the query
    /// would come back as two rows reading identically, with
    /// nothing to tell the swatch grid from the bar's own card.
    /// (The ORDER decides which comes first and is settled
    /// separately, in `SettingsDestination.thisProfile`; it is
    /// not what makes the titles distinct.) The two bar titles
    /// are the retired interim cards' keys, so their eleven
    /// translations carry straight over.
    let bordersGroup = SettingsControl(
        "colors.borders.title",
        "Border colors"
    )
    let dragGroup = SettingsControl(
        "colors.drag.title",
        "Drag colors"
    )
    let spaceBarGroup = SettingsControl(
        "space_bar.colors.title",
        "Space Bar colors"
    )
    let spaceBarMore = SettingsDrawer(
        "colors.more",
        "More colors",
        instance: "space_bar"
    )
    let appBarGroup = SettingsControl(
        "app_bar.global_colors.title",
        "App Bar colors"
    )
    let appBarMore = SettingsDrawer(
        "colors.more",
        "More colors",
        instance: "app_bar"
    )
}

/// Gaps & Borders — the structure half of the old Appearance
/// destination, renamed with its page in #678 Phase 3.
struct GapsAndBordersControls: Sendable {
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
    /// The shared-decisions card (#754). Titled for all three
    /// strokes it drives, not for any one of them — the Focus
    /// border card keeps `border.title` beneath it.
    let bordersCard = SettingsControl("borders.title", "Borders")
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
}

struct BehaviorControls: Sendable {
    let mouseCard = SettingsControl(
        "behavior.mouse.title",
        "Mouse"
    )
    let quitCard = SettingsControl("behavior.quit.title", "On quit")
}
