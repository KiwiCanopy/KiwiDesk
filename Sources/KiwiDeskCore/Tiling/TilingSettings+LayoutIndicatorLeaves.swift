import Foundation

/// The per-layout App Bar indicator leaves (#2368): the one list a
/// picked look clears, the tour's undo restores, and wearing the
/// shared look keeps.
extension TilingSettings {
    public static var layoutIndicatorLeaves:
        [WritableKeyPath<Self, AppBarStyle.ActiveIndicator?>]
    {
        [
            \.monocle.appBar.activeIndicator,
            \.scrolling.appBar.activeIndicator,
        ]
    }
}
