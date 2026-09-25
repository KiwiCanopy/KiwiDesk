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
        let frame = context.usable
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
        // Park (#881): the engine HOLDS the shown member across a
        // float focus (`monocleShownMembers`) so a float taking
        // focus cannot swap the members beneath it. Each member
        // parks its OWN effective frame — a full-width park of a
        // narrower window would push its body past the peek.
        let shown = Self.shownMember(
            anchor: context.focused,
            of: windows
        )
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
}
