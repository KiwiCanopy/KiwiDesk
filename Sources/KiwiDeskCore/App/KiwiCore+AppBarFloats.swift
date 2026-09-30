import Foundation

/// The App Bar's float section (#1826): the Space's floats, listed
/// after the tiled row behind a break. They have no slot in the
/// row, so they never enter `barGroups` — which the drag reorder
/// indexes. A focused float takes the highlight, and the bar's
/// scroll follows it there like any other item.
extension KiwiCore {
    /// The floats the directional focus keys reach (#488): flagged,
    /// no transient overlay (#683), no fullscreen, a travelling
    /// sticky one on the Space it renders on (#414).
    func appBarFloats(in space: Space) -> [WindowID] {
        state.floatingFocusCandidates(of: space)
    }

    /// The item index of the float holding `app`'s Space's focus —
    /// the system focus on the active Space, the remembered one
    /// elsewhere — or nil when no listed float holds it.
    func appBarFloatHighlight(of app: AppBarContent) -> Int? {
        let focus =
            app.space.id == activeSpace?.id
            ? state.workspaces.lastFocused : app.space.focused
        guard let focus, let index = app.floats.firstIndex(of: focus)
        else { return nil }
        return app.groups.count + index
    }
}
