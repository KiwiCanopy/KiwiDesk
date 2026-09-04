import CoreGraphics
import Foundation

/// Tunable tiling parameters shared between profile files and Lua config
/// (AGENTS.md §5).
public struct TilingSettings: Sendable, Equatable {
    public var gapsGlobal = Gaps()
    /// Space gap overrides (`gap.override[space_id]`).
    public var gapsOverride: [SpaceID: Gaps] = [:]
    public var minWindowSize: CGFloat = 300
    /// Global magnitude (points) the catalog AUTHORS Grow/Shrink
    /// keybindings with (`resize.step`, #58). Layout math never
    /// reads this — the bound row's own literal delta drives an
    /// actual resize.
    public var resizeStep: CGFloat = 50
    /// Sound alert when resize hotkey cannot act in layout (`resize.feedback`,
    /// #184).
    /// Whether a refusal pill also sounds (#1255). OFF by
    /// default (owner ruling 2026-09-05): the pill is the
    /// primary cue and the sound is an addition you switch on,
    /// so widening it from one near-unreachable case to every
    /// refusal makes no upgrade noisier.
    ///
    /// The DEFAULT alone does not deliver that: the encoder
    /// writes this key unconditionally, so every saved config
    /// carries an explicit `true` from the old default and would
    /// keep sounding. The one-shot migration carries it — safe
    /// because nobody chose the old value: it was audible in two
    /// rare cases, one of them reachable only by height-resizing
    /// a stack master.
    public var refusalSound = false
    /// Directional swap in cascade targets outer neighbor
    /// (`swap.skips_cascade`, #172).
    public var swapSkipsCascade = true
    /// Nudge float toward screen center on float toggle (`float.nudge`).
    public var floatNudge = true
    /// Scale float size proportionally on display change (#502,
    /// superseding #444/#493's keep-the-size). Read only by
    /// `FloatReanchor.target` at a display-crossing re-anchor,
    /// never by layout math — flipping it moves nothing. OFF keeps
    /// the exact pixel size and accepts the OS overflow (the
    /// narrow, technical ask — Lua-only, §2.7).
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
