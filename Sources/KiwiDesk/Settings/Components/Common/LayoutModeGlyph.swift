import KiwiDeskCore
import SwiftUI

/// Layout mode SF Symbol glyphs and curated tab ordering (#68 §6.3, #204).
extension LayoutMode {
    /// Ordered placement layouts for tab strip and search indexing
    /// (#90, #204).
    static let placementTabs: [LayoutMode] = [
        .bsp, .stack, .scrolling, .grid, .monocle, .track,
    ]

    var glyph: String {
        switch self {
        case .bsp:
            return "square.split.bottomrightquarter"
        case .stack:
            return "rectangle.leadinghalf.inset.filled"
        case .scrolling:
            return "arrow.left.and.right.square"
        case .grid:
            return "square.grid.3x3"
        case .monocle:
            return "rectangle.inset.filled"
        case .track:
            return "rectangle.split.3x1"
        case .floating:
            return "rectangle.on.rectangle"
        }
    }

    @MainActor var displayName: String {
        switch self {
        case .bsp: return L("layout.bsp.name", "BSP")
        case .stack: return L("layout.stack.name", "Stack")
        case .scrolling:
            return L("layout.scrolling.name", "Scrolling")
        case .grid: return L("layout.grid.name", "Grid")
        case .monocle:
            return L("layout.monocle.name", "Monocle")
        case .track:
            return L("layout.track.name", "Track")
        case .floating:
            return L("layout.floating.name", "Floating")
        }
    }
}
