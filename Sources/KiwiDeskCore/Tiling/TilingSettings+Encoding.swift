import CoreGraphics
import Foundation

/// The encode half of `TilingSettings`' Codable conformance,
/// split from `TilingSettings+Coding.swift` (which keeps the
/// keys and decode) for the 350-line file ceiling. Same
/// vocabulary rules apply (AGENTS.md §5).
extension TilingSettings {
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
        try container.encode(stickyStyle, forKey: .sticky)
        try container.encode(floatingStyle, forKey: .floating)
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
