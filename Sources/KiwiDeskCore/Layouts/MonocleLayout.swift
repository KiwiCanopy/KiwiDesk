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
                .centered(
                    in: frame,
                    generalizing: !context.probesBeyondBounds
                ) ?? frame
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
        // to `parkBounds` so the sliver clears both bars. The
        // shown member is the pan anchor (a tiled-sticky
        // traveler parks like a member and shows while it holds
        // the focus, #431), which the engine HOLDS across a
        // float focus (`monocleShownMembers`) so a float taking
        // focus cannot swap the members beneath it; with no
        // anchored member at all the front of the carousel
        // stands in, matching `new_window_placement`'s "front"
        // instinct. Parking each member's OWN effective frame
        // keeps a refused-width window's sliver on screen: a
        // full-width park of a narrower window would push its
        // body past the peek entirely.
        let shown = Self.shownMember(
            anchor: context.focused,
            of: windows
        )
        let corner = TilingEngine.optimalHideCorner(
            neighbors: context.screenNeighbors
        )
        let bounds = parkBounds(in: context)
        var result: [WindowID: CGRect] = [:]
        for window in windows {
            let own = effective(window)
            result[window] =
                window == shown
                ? own
                : TilingEngine.stashFrame(
                    own,
                    in: bounds,
                    corner: corner
                )
        }
        return result
    }

    /// The one copy of park's shown-member pick (#881, review
    /// round): the anchor while it is a member, else the front
    /// of the carousel. The navigate filter consumes the same
    /// rule (`KiwiCore+NavigateCommand`), so the tier it keeps
    /// and the member the layout shows cannot drift apart.
    static func shownMember(
        anchor: WindowID?,
        of members: [WindowID]
    ) -> WindowID? {
        anchor.flatMap {
            members.contains($0) ? $0 : nil
        } ?? members.first
    }

    /// The rect a park anchors to: the layout bounds, pulled in
    /// past the monocle bar's strip (#881 review round). The
    /// bar renders ABOVE windows on its edge, so a sliver
    /// anchored to the raw bounds would park underneath a
    /// bottom bar — enabled at the bottom by default — and the
    /// "thin edge stays visible" promise would be false. Only
    /// the bar's own edge moves; the Space Bar's strip is
    /// already carved from `context.bounds` by the engine
    /// (#293), which is also why the sliver clears a bottom
    /// Space Bar. Deliberately private rather than an
    /// `AppBarGeometry` op (§2.4, architect round): the
    /// "bounds pulled to the strip's near edge" arithmetic has
    /// this one consumer — home it beside `windowFrame` and
    /// `clampClear` when a second appears.
    private func parkBounds(
        in context: LayoutContext
    ) -> CGRect {
        var bounds = context.bounds
        guard
            let strip = context.monocle.barFrame(
                in: context.usable,
                global: context.appBarStyle
            )
        else { return bounds }
        switch context.monocle
            .resolvedBar(global: context.appBarStyle).edge
        {
        case .top:
            let cut = strip.maxY - bounds.minY
            bounds.origin.y += cut
            bounds.size.height = max(bounds.height - cut, 0)
        case .bottom:
            bounds.size.height = max(
                strip.minY - bounds.minY,
                0
            )
        case .left:
            let cut = strip.maxX - bounds.minX
            bounds.origin.x += cut
            bounds.size.width = max(bounds.width - cut, 0)
        case .right:
            bounds.size.width = max(
                strip.minX - bounds.minX,
                0
            )
        }
        return bounds
    }
}
