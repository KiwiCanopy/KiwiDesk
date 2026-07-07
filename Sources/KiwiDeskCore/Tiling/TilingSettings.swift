import CoreGraphics
import Foundation

/// Tunable tiling parameters (later fed from init.lua).
///
/// JSON naming mirrors the Lua API: a key is the Lua command
/// name with the `set_` verb stripped, grouped by namespace —
/// `set_gap_override` -> `gap.override`, `bsp.set_ratio` ->
/// `layout.bsp.ratio`. Profile files and `init.lua` share one
/// vocabulary (see AGENTS.md §5).
public struct TilingSettings: Sendable, Equatable, Codable {
    public var gapsGlobal = Gaps()
    /// `gap.override[space_id]` beats the global gaps.
    public var gapsOverride: [SpaceID: Gaps] = [:]
    public var minWindowSize: CGFloat = 300
    public var bsp = BspParams()
    public var stack = StackParams()
    public var scrolling = ScrollingParams()
    public var grid = GridParams()
    public var monocle = MonocleParams()
    /// The indicator bar's global look, shared by every layout
    /// that shows a bar. Each layout's own `bar` (enabled +
    /// overrides) resolves against this.
    public var appBarStyle = AppBarStyle()
    /// `new_window_placement_override[space_id]` beats the
    /// layout's own spawn placement (like the gap override).
    public var placementOverride: [SpaceID: SpawnPlacement] =
        [:]
    /// Drag visuals (see DragOverlay): the dragged window's
    /// own slot (ghost) and the swap target slot (drop zone).
    public var dragGhost = DragVisual.ghostDefault
    public var dragDropZone = DragVisual.dropZoneDefault
    /// Corner rounding of both visuals — tune it to match
    /// the window corners of the running macOS release.
    public var dragCornerRadius: CGFloat = 16
    /// Per-trigger animation toggles (`animations.*`).
    public var animations = AnimationSettings()
    /// What resizing a tiled window with the mouse does.
    public var mouseResize: MouseResizeMode = .layout

    public init() {}

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case animations
        case appBar = "app_bar"
        case drag
        case gap
        case layout
        case minWindowSize = "min_window_size"
        case placementOverride =
            "new_window_placement_override"
        case mouseResize = "mouse_resize"
    }

    private enum DragKeys: String, CodingKey {
        case cornerRadius = "corner_radius"
        case dropZone = "drop_zone"
        case ghost
    }

    private enum GapKeys: String, CodingKey {
        case global
        case `override`
    }

    private enum LayoutKeys: String, CodingKey {
        case bsp
        case grid
        case monocle
        case scroll
        case stack
    }

    private typealias Container =
        KeyedDecodingContainer<CodingKeys>

    /// Manual decoding: profiles saved before a field existed
    /// must keep loading (missing keys fall back to defaults).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        minWindowSize =
            try container.decodeIfPresent(
                CGFloat.self,
                forKey: .minWindowSize
            ) ?? 300
        placementOverride =
            try container.decodeIfPresent(
                [SpaceID: SpawnPlacement].self,
                forKey: .placementOverride
            ) ?? [:]
        appBarStyle =
            try container.decodeIfPresent(
                AppBarStyle.self,
                forKey: .appBar
            ) ?? AppBarStyle()
        animations =
            try container.decodeIfPresent(
                AnimationSettings.self,
                forKey: .animations
            ) ?? AnimationSettings()
        mouseResize =
            try container.decodeIfPresent(
                MouseResizeMode.self,
                forKey: .mouseResize
            ) ?? .layout
        try decodeGap(from: container)
        try decodeLayout(from: container)
        try decodeDrag(from: container)
    }

    private mutating func decodeGap(
        from container: Container
    ) throws {
        guard container.contains(.gap) else { return }
        let gap = try container.nestedContainer(
            keyedBy: GapKeys.self,
            forKey: .gap
        )
        gapsGlobal =
            try gap.decodeIfPresent(
                Gaps.self,
                forKey: .global
            ) ?? Gaps()
        gapsOverride =
            try gap.decodeIfPresent(
                [SpaceID: Gaps].self,
                forKey: .override
            ) ?? [:]
    }

    private mutating func decodeLayout(
        from container: Container
    ) throws {
        guard container.contains(.layout) else { return }
        let layout = try container.nestedContainer(
            keyedBy: LayoutKeys.self,
            forKey: .layout
        )
        bsp =
            try layout.decodeIfPresent(
                BspParams.self,
                forKey: .bsp
            ) ?? BspParams()
        grid =
            try layout.decodeIfPresent(
                GridParams.self,
                forKey: .grid
            ) ?? GridParams()
        monocle =
            try layout.decodeIfPresent(
                MonocleParams.self,
                forKey: .monocle
            ) ?? MonocleParams()
        scrolling =
            try layout.decodeIfPresent(
                ScrollingParams.self,
                forKey: .scroll
            ) ?? ScrollingParams()
        stack =
            try layout.decodeIfPresent(
                StackParams.self,
                forKey: .stack
            ) ?? StackParams()
    }

    private mutating func decodeDrag(
        from container: Container
    ) throws {
        guard container.contains(.drag) else { return }
        let drag = try container.nestedContainer(
            keyedBy: DragKeys.self,
            forKey: .drag
        )
        dragCornerRadius =
            try drag.decodeIfPresent(
                CGFloat.self,
                forKey: .cornerRadius
            ) ?? 16
        if drag.contains(.ghost) {
            dragGhost = try DragVisual(
                from: drag.superDecoder(forKey: .ghost),
                defaults: .ghostDefault
            )
        }
        if drag.contains(.dropZone) {
            dragDropZone = try DragVisual(
                from: drag.superDecoder(forKey: .dropZone),
                defaults: .dropZoneDefault
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(
            minWindowSize,
            forKey: .minWindowSize
        )
        try container.encode(
            placementOverride,
            forKey: .placementOverride
        )
        try container.encode(appBarStyle, forKey: .appBar)
        try container.encode(animations, forKey: .animations)
        try container.encode(mouseResize, forKey: .mouseResize)
        var gap = container.nestedContainer(
            keyedBy: GapKeys.self,
            forKey: .gap
        )
        try gap.encode(gapsGlobal, forKey: .global)
        try gap.encode(gapsOverride, forKey: .override)
        var layout = container.nestedContainer(
            keyedBy: LayoutKeys.self,
            forKey: .layout
        )
        try layout.encode(bsp, forKey: .bsp)
        try layout.encode(grid, forKey: .grid)
        try layout.encode(monocle, forKey: .monocle)
        try layout.encode(scrolling, forKey: .scroll)
        try layout.encode(stack, forKey: .stack)
        var drag = container.nestedContainer(
            keyedBy: DragKeys.self,
            forKey: .drag
        )
        try drag.encode(
            dragCornerRadius,
            forKey: .cornerRadius
        )
        try drag.encode(dragGhost, forKey: .ghost)
        try drag.encode(dragDropZone, forKey: .dropZone)
    }

    // MARK: - Resolution

    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
    }

    /// The scrolling params effective for `space`: the global
    /// params with that space's optional overrides merged on top
    /// (#17). Falls back to the global params when unoverridden.
    public func resolvedScrolling(
        for space: SpaceID
    ) -> ScrollingParams {
        scrolling.override[space]?.resolved(onto: scrolling)
            ?? scrolling
    }

    public func context(
        bounds: CGRect,
        space: Space
    ) -> LayoutContext {
        LayoutContext(
            bounds: bounds,
            gaps: gaps(for: space.id),
            focused: space.focused,
            minWindowSize: minWindowSize,
            bsp: bsp,
            stack: stack,
            scrolling: resolvedScrolling(for: space.id),
            grid: grid,
            monocle: monocle,
            appBarStyle: appBarStyle
        )
    }
}
