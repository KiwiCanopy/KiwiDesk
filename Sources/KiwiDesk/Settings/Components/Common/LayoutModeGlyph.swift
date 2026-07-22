import KiwiDeskCore
import SwiftUI

/// One glyph per layout mode (#68 §6.3), used wherever a mode
/// is named — the space rows' mode picker, the Layout Defaults
/// section headers, the App Bar override headers, the preset
/// thumbnails — so the association gets learned. The glyph is
/// never the only signifier; it always accompanies the label.
extension LayoutMode {
    /// The placement layouts in the order the Layout Defaults
    /// pane taught them (#204) — not `allCases` order, and
    /// without Floating. The one home for that curated list:
    /// the tab strip renders it and the sidebar search indexes
    /// it, so the two can't drift (review of #90).
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
        case .bsp: return L("layout.bsp.name", "Bsp")
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
