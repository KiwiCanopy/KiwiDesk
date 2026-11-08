import Foundation

/// Monocle's "Maximize windows" (#2976): every member at the
/// screen's visible frame with gaps 0, both bars read as Hidden in
/// that layout and the pocket resting nowhere. Never a stand-down
/// (`shelfStandsDown`), so a bar's shortcut, the Space slide and the
/// cues keep working; the ruling is `docs/design-decisions.md` ▸
/// Monocle's "Maximize windows" hides the bars.
extension TilingSettings {
    /// Whether a Space laid out in `mode` maximizes every window.
    public func maximizesWindows(in mode: LayoutMode) -> Bool {
        mode == .monocle && monocle.maximizeWindows
    }

    /// The bars' visibility a Space laid out in `mode` reads: each
    /// bar's own, or Hidden for both where `mode` maximizes its
    /// windows; the App Bar nil where the layout carries none. The
    /// ONE per-mode step every at-rest, reveal and reservation
    /// answer takes, so none reads the stored values beside it.
    public func barVisibilities(
        in mode: LayoutMode
    ) -> (space: ShelfVisibility, app: ShelfVisibility?) {
        let app = appBarVisibility(in: mode)
        guard maximizesWindows(in: mode) else {
            return (spaceBarStyle.visibility, app)
        }
        return (.hidden, app.map { _ in .hidden })
    }

    /// `barEdges(space:app:)` over the visibilities `mode` reads.
    public func barEdges(in mode: LayoutMode) -> [ShelfEdge] {
        let shown = barVisibilities(in: mode)
        return barEdges(space: shown.space, app: shown.app)
    }

    /// The gaps `space`'s layout input takes: none where its layout
    /// maximizes its windows, so every member, a parked one too,
    /// holds the whole frame up front and a focus step stays a raise
    /// (#2099); else the Space's own.
    public func layoutGaps(for space: Space) -> Gaps {
        guard maximizesWindows(in: space.mode) else {
            return gaps(for: space.id)
        }
        return Gaps(
            outer: .init(top: 0, bottom: 0, left: 0, right: 0),
            inner: .init(horizontal: 0, vertical: 0)
        )
    }

    /// Whether the pocket rests on screen in `mode`: its Show is not
    /// Hidden and `mode` does not maximize its windows, where a
    /// handle at rest would sit on the window (#2976 ▸ 4).
    public func pocketRests(in mode: LayoutMode) -> Bool {
        pocketRests && !maximizesWindows(in: mode)
    }
}
