import CoreGraphics

/// Monocle: every window is maximized to the full usable area.
///
/// All windows share the same frame; whichever is focused sits
/// on top, the rest are hidden behind it — or, with
/// `hide_style = park` (#881), the unfocused members park at
/// the stash corner so a transparent body or a centered
/// width-bound window (#677) cannot reveal them. No geometry
/// splitting regardless of window count. With the indicator bar
/// enabled, its strip is carved out of the usable area first,
/// so windows and bar never overlap and both stay on the
/// monitor.
public struct MonocleLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let frame = context.monocle.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        // A window whose app refuses the monocle size (#677)
        // takes the learned answer CENTERED in the slot —
        // residue split symmetrically instead of piling on one
        // side. Only the refused ask consumes; anything else
        // asks the full frame.
        func effective(_ window: WindowID) -> CGRect {
            context.sizeBounds[window]?
                .centered(in: frame) ?? frame
        }
        guard context.monocle.hideStyle == .park else {
            var result: [WindowID: CGRect] = [:]
            for window in windows {
                result[window] = effective(window)
            }
            return result
        }
        // Park (#881): only the shown member takes its slot;
        // every other member parks at the stash corner — the
        // space stash's own geometry and sliver trade, anchored
        // to the layout bounds (a bottom Space Bar strip lifts
        // the sliver clear of the bar). The
        // shown member is the pan anchor (a tiled-sticky
        // traveler parks like a member and shows while it holds
        // the focus, #431); with no anchored member — a focused
        // float above the space — the front of the carousel
        // stands in, matching `new_window_placement`'s "front"
        // instinct. Parking each member's OWN effective frame
        // keeps a refused-width window's sliver on screen: a
        // full-width park of a narrower window would push its
        // body past the peek entirely.
        let shown =
            context.focused.flatMap { focused in
                windows.contains(focused) ? focused : nil
            } ?? windows.first
        let corner = TilingEngine.optimalHideCorner(
            neighbors: context.screenNeighbors
        )
        var result: [WindowID: CGRect] = [:]
        for window in windows {
            let own = effective(window)
            result[window] =
                window == shown
                ? own
                : TilingEngine.stashFrame(
                    own,
                    in: context.bounds,
                    corner: corner
                )
        }
        return result
    }
}
