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
    /// `new_window_placement_override[space_id]` beats the
    /// layout's own spawn placement (like the gap override).
    public var placementOverride: [SpaceID: SpawnPlacement] =
        [:]
    /// Drag-and-drop visuals (consumed once D&D lands).
    public var dragShowGhost = true
    public var dragShowDropZone = true

    public init() {}

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case drag
        case gap
        case layout
        case minWindowSize = "min_window_size"
        case placementOverride =
            "new_window_placement_override"
    }

    private enum DragKeys: String, CodingKey {
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
        dragShowGhost =
            try drag.decodeIfPresent(
                Bool.self,
                forKey: .ghost
            ) ?? true
        dragShowDropZone =
            try drag.decodeIfPresent(
                Bool.self,
                forKey: .dropZone
            ) ?? true
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
        try layout.encode(scrolling, forKey: .scroll)
        try layout.encode(stack, forKey: .stack)
        var drag = container.nestedContainer(
            keyedBy: DragKeys.self,
            forKey: .drag
        )
        try drag.encode(dragShowGhost, forKey: .ghost)
        try drag.encode(dragShowDropZone, forKey: .dropZone)
    }

    // MARK: - Resolution

    public func gaps(for space: SpaceID) -> Gaps {
        gapsOverride[space] ?? gapsGlobal
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
            scrolling: scrolling,
            grid: grid
        )
    }
}
