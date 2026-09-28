import AppKit

/// Core's answer for an App Bar item's hover title (#1514), set
/// once at bootstrap and shared by every item.
@MainActor
final class AppBarHoverTitle {
    /// The window, the item's group size, and the text the item
    /// drew in full (nil when it drew none or cut it); nil back
    /// shows no tooltip.
    var read: @MainActor (WindowID, Int, String?) -> String? = {
        _,
        _,
        _ in nil
    }
}

/// The hover title is asked for when it shows, never stored, so a
/// renamed window needs no refresh (bars.md).
extension AppBarItemView: NSViewToolTipOwner {
    /// The item's text when the label draws all of it; nil when
    /// the label is hidden (icon content, a vertical bar) or its
    /// width truncates it.
    var fullyDrawnText: String? {
        guard !label.isHidden, let cell = label.cell else {
            return nil
        }
        return ceil(cell.cellSize.width) <= label.frame.width + 0.5
            ? text : nil
    }

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
        hoverTitle?.read(windowID, count, fullyDrawnText) ?? ""
    }
}
