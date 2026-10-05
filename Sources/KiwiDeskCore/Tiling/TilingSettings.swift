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
    /// Directional swap in cascade targets outer neighbor
    /// (`swap.skips_cascade`, #172).
    public var swapSkipsCascade = true
    /// Where an explicit float verb lands a window
    /// (`float_placement`); read only when one fires.
    public var floatPlacement: FloatPlacement = .center
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
    /// The shelf both bars sit on (`kiwishelf.*`, #1517).
    public var kiwishelf = KiwiShelf()
    /// The App Bar's own style (`app_bar.*`); per layout,
    /// `LayoutAppBar` overrides it.
    public var appBarStyle = AppBarStyle()
    /// Space Bar overview settings (`space_bar.*`, #293).
    public var spaceBarStyle = SpaceBarStyle()

    /// Liquid Glass on the ⌃⌥K shortcuts panel. Profile-scoped
    /// beside the two bars so ONE Settings row writes all three
    /// leaves (#1307); the panel reads the active profile.
    /// Defaults ON with them (owner ruling 2026-09-10), so the
    /// row's "all three" reading is never false on a fresh setup.
    public var shortcutPanelLiquidGlass = true
    /// Liquid Glass on the Space switch's plates (#1956), a leaf of
    /// the same switch; off, they take the material.
    public var spaceSwitchLiquidGlass = true
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
    /// Liquid Glass on the drag ghost and drop zone (#1620) — one
    /// leaf for both markers, written by the one Liquid Glass row
    /// beside the shelf's and the panel's (#1307).
    public var dragLiquidGlass = true
    /// Per-trigger animation settings (`animations.*`).
    public var animations = AnimationSettings()
    /// Mouse drag resize mode for tiled windows.
    public var mouseResize: MouseResizeMode = .layout
    /// Mouse tracking and focus settings (`mouse.*`, #186).
    public var mouse = MouseSettings()
    /// Optional display icon per space (`space.icon[space_id]`, #68).
    public var spaceIcons: [SpaceID: String] = [:]

    public init() {}
}
