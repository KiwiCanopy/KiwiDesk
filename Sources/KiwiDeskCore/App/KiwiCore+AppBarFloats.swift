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

    /// The item that renders focused: the focus anchor's float
    /// item, else the tiled group holding it. One reading of the
    /// focus (`appBarFocused`) and of which items float
    /// (`Item.floating`), so no index arithmetic restates the
    /// order `appBarContent` builds.
    func appBarActiveIndex(of app: AppBarContent) -> Int? {
        guard let focus = appBarFocused(of: app.space) else {
            return nil
        }
        return app.items.firstIndex { $0.floating && $0.id == focus }
            ?? app.groups.firstIndex { $0.contains(focus) }
    }
}
