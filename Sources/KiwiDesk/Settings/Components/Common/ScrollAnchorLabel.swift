import KiwiDeskCore
import SwiftUI

/// What the Focus-anchor picker calls each `ScrollingParams.Anchor`
/// (#239, #753).
///
/// Two pickers offer the anchor — the Layout Defaults card and the
/// per-space override row — and both build their options by
/// mapping `ScrollingParams.Anchor.allCases` through this, so a
/// fifth anchor reaches the user without either of them being
/// edited. Hand-listing the four in each picker is what made the
/// enum's `CaseIterable` an assertion-only affordance: three test
/// sweeps would have covered a new case while the two places a
/// user actually picks one silently omitted it.
///
/// **The picker's on-screen order is therefore the enum's
/// declaration order**, which is what a reader of either call site
/// sees; reordering the cases reorders the segments.
///
/// `start` / `end` are axis-relative and the label names the
/// concrete edge for the current orientation (Top/Bottom vertical,
/// Left/Right horizontal) — presentation only, the stored value
/// staying orientation-neutral. That branch is the reason this is
/// a function of the orientation rather than a table on the enum,
/// and the reason it lives in `Common/`: Core names the anchor,
/// the GUI narrates the edge (#96).
/// `@MainActor` because `L()` is: the labels resolve through the
/// live catalog, exactly as they did inline in each picker.
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
