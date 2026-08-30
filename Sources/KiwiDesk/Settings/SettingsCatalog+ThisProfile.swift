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

/// Colors & Animations catalog controls (#678 Phase 3).
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
    let motionMore = SettingsDrawer(
        "motion.more",
        "Per-event and duration"
    )
}

/// Advanced Colors catalog controls (#678 Phase 3, #277, #793).
struct AdvancedColorsControls: Sendable {
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
    let stickyWindows = SettingsControl(
        "sticky.title",
        "Sticky windows"
    )
}

/// Bars catalog controls (#293, #277).
struct BarsControls: Sendable {
    let spaceBarCard = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar"
    )
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
