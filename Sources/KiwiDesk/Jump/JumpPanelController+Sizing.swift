import AppKit
import KiwiDeskCore

/// Jump to window's size (#1875 ▸ Panel): the list grows to a
/// third of the screen and the panel follows its results.
extension JumpPanelController {
    /// The most rows the list shows: a third of the screen's
    /// visible height, never fewer than 8 nor more than 10
    /// (#2229).
    static func rowCap(visibleHeight: CGFloat) -> Int {
        let rows = Int(visibleHeight / 3 / JumpRowView.height)
        return min(max(rows, 8), 10)
    }

    /// The panel's width: `JumpPanelView.width`, kept 40 pt clear
    /// of each edge of a narrower screen.
    static func width(visibleWidth: CGFloat) -> CGFloat {
        min(JumpPanelView.width, visibleWidth - 80)
    }

    /// Where the panel's top — its field — sits: Spotlight's, so
    /// the field lands where a search field is looked for and the
    /// list grows down from it (#2229). Measured on macOS 27:
    /// Spotlight's field top 278 pt below the visible area's top
    /// of 1083 pt, on a 1728×1117 screen. One screen size, so
    /// whether it scales or holds a fixed offset is unmeasured.
    static let topFraction: CGFloat = 0.257

    /// The panel's origin on `visible`: centred across, its top at
    /// `topFraction`, and lifted where a tall panel would run past
    /// the bottom.
    static func origin(size: CGSize, visible: CGRect) -> CGPoint {
        let top = visible.maxY - visible.height * topFraction
        let bottom = max(top - size.height, visible.minY)
        return CGPoint(x: visible.midX - size.width / 2, y: bottom)
    }

    /// Fits the panel to its list, keeping the top edge where it
    /// is so the field stays under the user's eyes; a scope switch
    /// glides there (#2229), at once under Reduce Motion.
    func refit(animated: Bool = false) {
        guard let panel, panel.isVisible,
            let content = panel.contentView
        else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        let top = panel.frame.maxY
        let frame = NSRect(
            x: panel.frame.minX,
            y: top - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(
            frame,
            display: true,
            animate: animated && !reduceMotion()
        )
    }

    /// Each app's icon, read once per opening.
    static func icons(
        for snapshot: JumpSnapshot
    ) -> [pid_t: NSImage] {
        var icons: [pid_t: NSImage] = [:]
        for pid in Set(snapshot.entries.map(\.pid)) {
            icons[pid] =
                NSRunningApplication(processIdentifier: pid)?.icon
        }
        return icons
    }
}
