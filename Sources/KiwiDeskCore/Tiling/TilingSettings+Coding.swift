import CoreGraphics
import Foundation

/// The Codable half of `TilingSettings`, split from the
/// struct definition for the 350-line file ceiling. JSON
/// naming mirrors the Lua API (one vocabulary, AGENTS.md
/// §5); `SettingsCodingTests` pins the shape.
///
/// The conformance is declared here, with its implementation:
/// declared on the struct, a gutted extension would let the
/// compiler silently synthesize camelCase/flat coding — this
/// way it is a compile error instead.
extension TilingSettings: Codable {
    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case animations
        case appBar = "app_bar"
        case spaceBar = "space_bar"
        case border
        case drag
        case gap
        case layout
        case minWindowSize = "min_window_size"
        case swapSkipsCascade = "swap_skips_cascade"
        case placementOverride =
            "new_window_placement_override"
        case mouse
        case mouseResize = "mouse_resize"
        case quit
        case resize
        case space
    }

    private enum QuitKeys: String, CodingKey {
        case layout
        case gridTargetDepth = "grid_target_depth"
    }

    private enum SpaceKeys: String, CodingKey {
        case icon
    }

    private enum ResizeKeys: String, CodingKey {
        case feedback
        case step
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
        case track
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
        swapSkipsCascade =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .swapSkipsCascade
            ) ?? true
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
        spaceBarStyle =
            try container.decodeIfPresent(
                SpaceBarStyle.self,
                forKey: .spaceBar
            ) ?? SpaceBarStyle()
        borderStyle =
            try container.decodeIfPresent(
                BorderStyle.self,
                forKey: .border
            ) ?? BorderStyle()
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
        mouse =
            try container.decodeIfPresent(
                MouseSettings.self,
                forKey: .mouse
            ) ?? MouseSettings()
        try decodeGap(from: container)
        try decodeLayout(from: container)
        try decodeDrag(from: container)
        try decodeSpace(from: container)
        try decodeResize(from: container)
        try decodeQuit(from: container)
    }

    private mutating func decodeQuit(
        from container: Container
    ) throws {
        guard container.contains(.quit) else { return }
        let quit = try container.nestedContainer(
            keyedBy: QuitKeys.self,
            forKey: .quit
        )
        quitLayout =
            try quit.decodeIfPresent(
                QuitLayoutStyle.self,
                forKey: .layout
            ) ?? .grid
        // Clamp on decode (the `clampedWidth` precedent): a
        // hand-edited profile can't smuggle a value past the
        // range the command and GUI enforce.
        let range = QuitGridLayout.targetDepthRange
        quitGridTargetDepth =
            (try quit.decodeIfPresent(
                Int.self,
                forKey: .gridTargetDepth
            )).map {
                min(
                    max($0, range.lowerBound),
                    range.upperBound
                )
            } ?? QuitGridLayout.defaultTargetDepth
    }

    private mutating func decodeResize(
        from container: Container
    ) throws {
        guard container.contains(.resize) else { return }
        let resize = try container.nestedContainer(
            keyedBy: ResizeKeys.self,
            forKey: .resize
        )
        resizeStep =
            try resize.decodeIfPresent(
                CGFloat.self,
                forKey: .step
            ) ?? 50
        resizeFeedback =
            try resize.decodeIfPresent(
                Bool.self,
                forKey: .feedback
            ) ?? true
    }

    private mutating func decodeSpace(
        from container: Container
    ) throws {
        guard container.contains(.space) else { return }
        let space = try container.nestedContainer(
            keyedBy: SpaceKeys.self,
            forKey: .space
        )
        spaceIcons =
            try space.decodeIfPresent(
                [SpaceID: String].self,
                forKey: .icon
            ) ?? [:]
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
        track =
            try layout.decodeIfPresent(
                TrackParams.self,
                forKey: .track
            ) ?? TrackParams()
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
            swapSkipsCascade,
            forKey: .swapSkipsCascade
        )
        try container.encode(
            placementOverride,
            forKey: .placementOverride
        )
        try container.encode(appBarStyle, forKey: .appBar)
        try container.encode(spaceBarStyle, forKey: .spaceBar)
        try container.encode(borderStyle, forKey: .border)
        try container.encode(animations, forKey: .animations)
        try container.encode(mouseResize, forKey: .mouseResize)
        try container.encode(mouse, forKey: .mouse)
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
        try layout.encode(track, forKey: .track)
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
        var space = container.nestedContainer(
            keyedBy: SpaceKeys.self,
            forKey: .space
        )
        try space.encode(spaceIcons, forKey: .icon)
        var resize = container.nestedContainer(
            keyedBy: ResizeKeys.self,
            forKey: .resize
        )
        try resize.encode(resizeStep, forKey: .step)
        try resize.encode(resizeFeedback, forKey: .feedback)
        var quit = container.nestedContainer(
            keyedBy: QuitKeys.self,
            forKey: .quit
        )
        try quit.encode(quitLayout, forKey: .layout)
        try quit.encode(
            quitGridTargetDepth,
            forKey: .gridTargetDepth
        )
    }
}
