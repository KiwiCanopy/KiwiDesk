import AppKit

/// Core's answers for App Bar items, set once at bootstrap and
/// shared by every item — the App Bar's twin of
/// `SpaceBarGlyphActions`, where #1518's menu joins it.
@MainActor
final class AppBarItemActions {
    /// The hover title for a window and the item's group size,
    /// read when the tooltip shows (#1514).
    var tooltip: @MainActor (WindowID, Int) -> String? = { _, _ in
        nil
    }
}

/// The hover title is asked for when it shows, never stored, so a
/// renamed window needs no refresh (bars.md).
extension AppBarItemView: NSViewToolTipOwner {
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

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let tipTag { removeToolTip(tipTag) }
        tipTag = addToolTip(bounds, owner: self, userData: nil)
    }

    func view(
        _ view: NSView,
        stringForToolTip tag: NSView.ToolTipTag,
        point: NSPoint,
        userData data: UnsafeMutableRawPointer?
    ) -> String {
        guard hidesText else { return "" }
        return itemActions?.tooltip(windowID, count) ?? ""
    }
}
