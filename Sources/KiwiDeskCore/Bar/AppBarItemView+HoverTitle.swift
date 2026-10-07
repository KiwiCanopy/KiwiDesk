import AppKit

/// Core's answers for App Bar items, set once at bootstrap and
/// shared by every item — the App Bar's twin of
/// `SpaceBarGlyphActions`, where #1518's menu joins it.
@MainActor
final class AppBarItemActions {
    /// The bars' one hover peek (#1946), which reads the item's
    /// windows when it shows, so a renamed window needs no
    /// refresh (bars.md).
    weak var peek: BarPeek?
}

/// The item's hover peek (#1946): asked for only where the item
/// hides text (#1514's ruling).
extension AppBarItemView {
    /// Whether the label shows all of its text: false when it is
    /// hidden (icon content, a vertical bar) or its width cuts it.
    var drawsTextInFull: Bool {
        guard !label.isHidden, let cell = label.cell else {
            return false
        }
        return ceil(cell.cellSize.width) <= label.frame.width + 0.5
    }

    /// The item hides text: Core cut the title, or the label
    /// does not show all of it (#1514's ruling).
    var hidesText: Bool { titleCut || !drawsTextInFull }

    /// What the peek shows for this item: its windows, where it
    /// hides text; nil where it draws everything already.
    var peekSource: BarPeekSource? {
        hidesText ? .appItem(members) : nil
    }

    /// Reports the pointer's reading to the peek — every hover
    /// reading, the relayout's re-read included.
    func reportPeek(ownsPointer: Bool) {
        itemActions?.peek?.pointer(
            in: self,
            on: ownsPointer ? self : nil,
            source: ownsPointer ? peekSource : nil,
            edge: edge
        )
    }
}
