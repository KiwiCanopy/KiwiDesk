import KiwiDeskCore
import SwiftUI

/// Layout mode names and curated tab ordering (#68 §6.3, #204).
/// The symbol (`LayoutMode.symbol`, Core's) is never the only
/// signifier in Settings — it always accompanies the label.
extension LayoutMode {
    /// Ordered placement layouts — NOT `allCases` order, and
    /// without Floating (#204). One home: the tab strip renders
    /// it and search indexes it, so the two can't drift (#90).
    static let placementTabs: [LayoutMode] = [
        .bsp, .stack, .scrolling, .grid, .monocle, .track,
    ]

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
