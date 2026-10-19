import KiwiDeskCore

// Settings catalog declarations for the "This Profile" sidebar group.

struct SpacesControls: Sendable {
    let spacesCard = SettingsControl("spaces.title", "Spaces")
    /// Detail panel per-Space preview (#794).
    let spacePreview = SettingsControl(
        "spaces.preview.title",
        "This Space's layout"
    )
}

struct LayoutDefaultsControls: Sendable {
    let minWindowSize = SettingsControl(
        "layout_defaults.min_window_size",
        "Minimum window size"
    )
    let minSizePerLayout = SettingsDrawer(
        "layout_defaults.min_size.per_layout",
        "Per layout",
        children: MinSizeDrawerControls()
    )
    let livePreview = SettingsControl(
        "layout_defaults.live_preview",
        "Live preview"
    )
    let spacesUsing = SettingsControl(
        "layout_defaults.spaces_using",
        "Spaces using this layout"
    )
}

/// The minimum window size's "Per layout" drawer (#2237): one
/// child per layout and axis, each a search anchor.
struct MinSizeDrawerControls: Sendable {
    let stackWidth = SettingsControl(
        "layout_defaults.min_size.stack_width",
        "Stack width"
    )
    let stackHeight = SettingsControl(
        "layout_defaults.min_size.stack_height",
        "Stack height"
    )
    let gridWidth = SettingsControl(
        "layout_defaults.min_size.grid_width",
        "Grid width"
    )
    let gridHeight = SettingsControl(
        "layout_defaults.min_size.grid_height",
        "Grid height"
    )
    let trackWidth = SettingsControl(
        "layout_defaults.min_size.track_width",
        "Track width"
    )
    let trackHeight = SettingsControl(
        "layout_defaults.min_size.track_height",
        "Track height"
    )
    let bspWidth = SettingsControl(
        "layout_defaults.min_size.bsp_width",
        "BSP width"
    )
    let bspHeight = SettingsControl(
        "layout_defaults.min_size.bsp_height",
        "BSP height"
    )
    let scrollingWidth = SettingsControl(
        "layout_defaults.min_size.scrolling_width",
        "Scrolling width"
    )
    let scrollingHeight = SettingsControl(
        "layout_defaults.min_size.scrolling_height",
        "Scrolling height"
    )
    let floatingWidth = SettingsControl(
        "layout_defaults.min_size.floating_width",
        "Floating width"
    )
    let floatingHeight = SettingsControl(
        "layout_defaults.min_size.floating_height",
        "Floating height"
    )
}

struct ScreensControls: Sendable {
    let spacePlacement = SettingsControl(
        "monitors.space_placement",
        "Space placement"
    )
    let orphanPins = SettingsControl(
        "monitors.orphan_pins.title",
        "Pinned to disconnected screens"
    )
    let screenFingerprints = SettingsDrawer(
        "monitors.advanced.title",
        "Screen fingerprints"
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

/// Colors & Animations catalog controls (#678 Phase 3).
struct ColorsControls: Sendable {
    let sharedLook = SettingsControl("looks.shared.title", "Shared look")
    let looksShelf = SettingsControl("looks.title", "Looks")
    let paletteShelf = SettingsControl(
        "palettes.title",
        "Color palette"
    )
    let currentScene = SettingsControl(
        "colors.scene.title",
        "Current colors"
    )
    let glassCard = SettingsControl(
        "colors.liquid_glass",
        "Liquid Glass"
    )
    let motionCard = SettingsControl(
        "behavior.animations.title",
        "Animations"
    )
    /// Declared with its children so a hit on a per-event
    /// toggle opens the drawer (#1250, #277).
    let motionMore = SettingsDrawer(
        "motion.more",
        "Per-event and duration",
        children: MotionMoreControls()
    )
}

/// Animations ▸ Per-event and duration rows, keyed on their
/// census label keys and declared in `ColorsRowOrder.motionMore`'s
/// order.
struct MotionMoreControls: Sendable {
    let animateWindowResizes = SettingsControl(
        "behavior.animations.window_resize",
        "Animate window resizes"
    )
    let animateWindowSwaps = SettingsControl(
        "behavior.animations.window_swap",
        "Animate window swaps"
    )
    let animateLayoutReflows = SettingsControl(
        "behavior.animations.relayout",
        "Animate layout reflows"
    )
    let animationDuration = SettingsControl(
        "behavior.animations.window_duration",
        "Window duration"
    )
    let animateShelf = SettingsControl(
        "behavior.animations.shelf",
        "Animate KiwiShelf"
    )
    let shelfDuration = SettingsControl(
        "behavior.animations.shelf_duration",
        "KiwiShelf duration"
    )
}

/// Advanced Colors catalog controls (#678 Phase 3, #277, #793,
/// #1857).
struct AdvancedColorsControls: Sendable {
    /// The two role groups (#1857).
    let accentGroup = SettingsControl("colors.accent.title", "Accent")
    let secondAccentGroup = SettingsControl(
        "colors.second_accent.title",
        "Second accent"
    )
    let kiwishelfGroup = SettingsControl(
        "kiwishelf.colors.title",
        "KiwiShelf colors"
    )
    let windowMarksGroup = SettingsControl(
        "colors.window_marks.title",
        "Window marks"
    )
    /// Detail panel full-palette preview (#793).
    let everyColorScene = SettingsControl(
        "colors.advanced.scene.title",
        "Every color at once"
    )
}

/// Gaps & Borders catalog controls (#678 Phase 3, #754).
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
    let bordersCard = SettingsControl(
        "border.shared.title",
        "Shared by all borders"
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
    /// The sticky and floating windows' card: both marks'
    /// switches and sticky's Desktop reach (#1799).
    let stickyWindows = SettingsControl(
        "sticky_floating.title",
        "Sticky & floating windows"
    )
}
