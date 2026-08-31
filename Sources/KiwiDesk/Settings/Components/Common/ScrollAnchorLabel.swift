import KiwiDeskCore
import SwiftUI

/// Localized label mapping for scrolling focus anchor options
/// (#96, #239, #753). Both pickers map
/// `ScrollingParams.Anchor.allCases` through this, so the on-screen
/// order IS the enum's declaration order; the label names the
/// concrete edge for the current orientation — presentation only.
@MainActor
enum ScrollAnchorLabel {
    static func text(
        for anchor: ScrollingParams.Anchor,
        isVertical: Bool
    ) -> String {
        switch anchor {
        case .center:
            return L("scroll_grid.anchor.center", "Center")
        case .start:
            return isVertical
                ? L("scroll_grid.anchor.start_v", "Top")
                : L("scroll_grid.anchor.start_h", "Left")
        case .end:
            return isVertical
                ? L("scroll_grid.anchor.end_v", "Bottom")
                : L("scroll_grid.anchor.end_h", "Right")
        case .follow:
            return L("scroll_grid.anchor.follow", "Follow")
        }
    }
}
