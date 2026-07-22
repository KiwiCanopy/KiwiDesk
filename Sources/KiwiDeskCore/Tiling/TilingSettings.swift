import CoreGraphics
import Foundation

/// Tunable tiling parameters (later fed from init.lua).
///
/// JSON naming mirrors the Lua API: a key is the Lua command
/// name with the `set_` verb stripped, grouped by namespace —
/// `set_gap_override` -> `gap.override`, `bsp.set_ratio` ->
/// `layout.bsp.ratio`. Profile files and `init.lua` share one
/// vocabulary (see AGENTS.md §5).
public struct TilingSettings: Sendable, Equatable {
    public var gapsGlobal = Gaps()
    /// `gap.override[space_id]` beats the global gaps.
    public var gapsOverride: [SpaceID: Gaps] = [:]
    public var minWindowSize: CGFloat = 300
    /// Global magnitude (points) the catalog *authors* Grow/Shrink
    /// keybindings with (`resize.step`, #58): it emits
    /// `resize("x", ±step)`, and import reads a recovered magnitude
    /// back into it. Layout math never reads this — the bound
    /// row's own literal delta drives an actual resize.
    public var resizeStep: CGFloat = 50
    /// When true (default), a resize hotkey that cannot act in
    /// the active layout (monocle, grid, floating space) plays
    /// the system alert sound (#184) — the "Cmd+Z with nothing
    /// to undo" idiom. Hotkey fires only: CLI/IPC callers read
    /// the error JSON and must stay silent. `resize.feedback`.
    public var resizeFeedback = true
    /// When true (default), a directional `swap` issued from
    /// inside an overflow cascade skips the other windows piled
    /// with the focused one and targets the tiled neighbor
    /// outside the pile (nothing when there is none), rather than
    /// reordering the cascade (#172). Global (per profile, all
    /// spaces), same tier as `minWindowSize`; power-user escape
    /// hatch, no GUI. `focus` is never affected.
    public var swapSkipsCascade = true
    /// When true (default), toggling a window tiled→floating
    /// gives it a small fixed shove toward the screen center so
    /// the state change is visible — a float otherwise keeps its
    /// exact frame, making the toggle look inert. Fires on the
    /// float direction only (`make_tiled` already animates a real
    /// move back into the layout). Global (per profile, all
    /// spaces), same tier as `swapSkipsCascade`; a niche polish
    /// toggle, Lua-only, no GUI. See `FloatNudge`.
    public var floatNudge = true
    public var bsp = BspParams()
    public var stack = StackParams()
    public var scrolling = ScrollingParams()
    public var grid = GridParams()
    public var monocle = MonocleParams()
    public var track = TrackParams()
    /// The indicator bar's global look, shared by every layout
    /// that shows a bar. Each layout's own `bar` (enabled +
    /// overrides) resolves against this.
    public var appBarStyle = AppBarStyle()
    /// The Space Bar (#293): per-display Spaces overview,
    /// layout-independent, global-only (no per-layout mirror).
    /// Its strip is reserved from the visible frame *before*
    /// layouts see their bounds (space-first reservation).
    public var spaceBarStyle = SpaceBarStyle()
    /// `new_window_placement_override[space_id]` beats the
    /// layout's own spawn placement (like the gap override).
    public var placementOverride: [SpaceID: SpawnPlacement] =
        [:]
    /// Focus-window border look (#278): the ring painted around
    /// the focused window (and, when enabled, unfocused ones).
    /// A pure post-layout overlay — never feeds back into layout.
    public var borderStyle = BorderStyle()
    /// Sticky-window indicator settings (#414): the on-window
    /// glyph marking a sticky window. A border sibling — pure
    /// post-layout overlay, never feeds back into layout.
    public var stickyStyle = StickyStyle()
    /// Floating-window mark settings (#429): the sticky pair's
    /// sibling. Just the Space Bar floating badge tint today —
    /// floating has no on-window chip.
    public var floatingStyle = FloatingStyle()
    /// Drag visuals (see DragOverlay): the dragged window's
    /// own slot (ghost) and the swap target slot (drop zone).
    public var dragGhost = DragVisual.ghostDefault
    public var dragDropZone = DragVisual.dropZoneDefault
    /// Corner rounding of both visuals — defaults to the shared
    /// system window radius (one source with the focus border,
    /// see `GeometryUtils.systemWindowCornerRadius`), still
    /// tunable per profile to match the running macOS release.
    public var dragCornerRadius = GeometryUtils
        .systemWindowCornerRadius
    /// Per-trigger animation toggles (`animations.*`).
    public var animations = AnimationSettings()
    /// What resizing a tiled window with the mouse does.
    public var mouseResize: MouseResizeMode = .layout
    /// Mouse-pointer behaviour (`mouse.*`, #186).
    public var mouse = MouseSettings()
    /// Optional recognition icon per space (#68): an SF Symbol
    /// name, an emoji, or a single character — the same grammar
    /// as mode icons. Sparse; the name stays primary everywhere.
    /// `space.icon[space_id]`.
    public var spaceIcons: [SpaceID: String] = [:]
    /// Quit-time teardown placement (#197): how remaining
    /// managed windows are spread when KiwiDesk exits.
    /// `quit.layout`; `grid` is the only strategy today.
    public var quitLayout: QuitLayoutStyle = .grid
    /// Density target of the quit grid (#281): the stack depth
    /// a cell aims for before the grid grows a dimension
    /// (still hard-clamped 2×2…4×4). `quit.grid_target_depth`.
    public var quitGridTargetDepth =
        QuitGridLayout.defaultTargetDepth

    public init() {}
}
