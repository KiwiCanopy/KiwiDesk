import CoreGraphics
import Foundation

/// Tunable tiling parameters shared between profile files and Lua config
/// (AGENTS.md §5).
public struct TilingSettings: Sendable, Equatable {
    public var gapsGlobal = Gaps()
    /// Space gap overrides (`gap.override[space_id]`).
    public var gapsOverride: [SpaceID: Gaps] = [:]
    public var minWindowSize: CGFloat = 300
    /// Global magnitude (points) for authored resize hotkeys (`resize.step`,
    /// #58).
    public var resizeStep: CGFloat = 50
    /// Sound alert when resize hotkey cannot act in layout (`resize.feedback`,
    /// #184).
    public var resizeFeedback = true
    /// Directional swap in cascade targets outer neighbor
    /// (`swap.skips_cascade`, #172).
    public var swapSkipsCascade = true
    /// Nudge float toward screen center on float toggle (`float.nudge`).
    public var floatNudge = true
    /// Scale float size proportionally on display change (#502, #444, #493).
    public var floatScaleOnDisplayChange = true
    public var bsp = BspParams()
    public var stack = StackParams()
    public var scrolling = ScrollingParams()
    public var grid = GridParams()
    public var monocle = MonocleParams()
    public var track = TrackParams()
    /// Global indicator bar style for layouts with a bar.
    public var appBarStyle = AppBarStyle()
    /// Space Bar overview settings (`space_bar.*`, #293).
    public var spaceBarStyle = SpaceBarStyle()
    /// Space spawn placement overrides (`placement.override[space_id]`).
    public var placementOverride: [SpaceID: SpawnPlacement] =
        [:]
    /// Focus ring appearance settings (`border.*`, #278).
    public var borderStyle = BorderStyle()
    /// Sticky window badge appearance (`sticky.*`, #414).
    public var stickyStyle = StickyStyle()
    /// Floating window badge appearance (`floating.*`, #429).
    public var floatingStyle = FloatingStyle()
    /// Drag ghost visual settings (`drag.ghost`).
    public var dragGhost = DragVisual.ghostDefault
    /// Drag drop zone visual settings (`drag.drop_zone`).
    public var dragDropZone = DragVisual.dropZoneDefault
    /// Corner radius for drag overlay visuals.
    public var dragCornerRadius = GeometryUtils
        .systemWindowCornerRadius
    /// Per-trigger animation settings (`animations.*`).
    public var animations = AnimationSettings()
    /// Mouse drag resize mode for tiled windows.
    public var mouseResize: MouseResizeMode = .layout
    /// Mouse tracking and focus settings (`mouse.*`, #186).
    public var mouse = MouseSettings()
    /// Optional display icon per space (`space.icon[space_id]`, #68).
    public var spaceIcons: [SpaceID: String] = [:]
    /// Window placement strategy on app quit (`quit.layout`, #197).
    public var quitLayout: QuitLayoutStyle = .grid
    /// Density target depth for quit grid (`quit.grid_target_depth`, #281).
    public var quitGridTargetDepth =
        QuitGridLayout.defaultTargetDepth

    public init() {}
}
