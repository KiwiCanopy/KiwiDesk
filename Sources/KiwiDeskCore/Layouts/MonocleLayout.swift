import CoreGraphics

/// Monocle layout: maximizes windows to usable area (#677, #881).
///
/// Unfocused windows stack underneath or park at stash corner when
/// `hide_style = park` (#881).
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
        // Center size-bound window in slot (#677).
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

    /// Selects active shown member for park mode (#431, #881,
    /// `KiwiCore+NavigateCommand`).
    static func shownMember(
        anchor: WindowID?,
        of members: [WindowID]
    ) -> WindowID? {
        anchor.flatMap {
            members.contains($0) ? $0 : nil
        } ?? members.first
    }

    /// Computes park anchor bounds accounting for bar insets (#293, #881).
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
