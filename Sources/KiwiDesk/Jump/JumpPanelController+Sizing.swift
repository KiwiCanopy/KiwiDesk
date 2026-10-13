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

    /// Fits the panel to its list, keeping the top edge where it
    /// is so the field stays under the user's eyes.
    func refit() {
        guard let panel, panel.isVisible,
            let content = panel.contentView
        else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        let top = panel.frame.maxY
        panel.setFrame(
            NSRect(
                x: panel.frame.minX,
                y: top - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
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
