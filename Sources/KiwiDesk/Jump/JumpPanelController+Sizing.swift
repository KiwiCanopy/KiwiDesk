import AppKit
import KiwiDeskCore

/// KiwiHub's size (#1875 ▸ Panel): one fixed ceiling on every
/// side, the panel following each side's content beneath it.
extension JumpPanelController {
    /// The Windows list's room, in rows: nine, the numbered reach,
    /// section headers drawn inside it (#2309).
    static let rowCap = JumpList.numbered

    /// The visible area with every KiwiShelf strip cut away by the
    /// edge Core says it sits on — the one home for where the panel
    /// may stand, read by its width, its place and the Shortcuts
    /// sheet's cap (#2246). `NSScreen.visibleFrame` leaves the shelf
    /// in. A top strip is ignored: the field stands below it at
    /// `topFraction`.
    static func clearArea(
        visible: CGRect,
        shelves: [ShelfFrame]
    ) -> CGRect {
        var area = visible
        for shelf in shelves where shelf.frame.intersects(visible) {
            let frame = shelf.frame
            switch shelf.edge {
            case .top:
                break
            case .bottom:
                let cut = max(frame.maxY - area.minY, 0)
                area.origin.y += cut
                area.size.height -= cut
            case .left:
                let cut = max(frame.maxX - area.minX, 0)
                area.origin.x += cut
                area.size.width -= cut
            case .right:
                area.size.width -= max(area.maxX - frame.minX, 0)
            }
        }
        return area
    }

    /// The Shortcuts side's tallest sheet: the panel runs from its
    /// field down to 40 pt above the clear area's bottom, never
    /// taller than `maxPanelHeight`, less the field, the button row
    /// and the footer (#2246).
    static func sheetCap(visible: CGRect, area: CGRect) -> CGFloat {
        let top = visible.maxY - visible.height * topFraction
        let below = top - area.minY - 40
        return max(min(below, maxPanelHeight) - shortcutsChrome, 200)
    }

    /// The tallest the panel stands on any side: compact, as
    /// Spotlight is, the Shortcuts sheet scrolling past it (#2309).
    static let maxPanelHeight: CGFloat = 400

    /// What the Shortcuts side draws besides its sheet: the field,
    /// the button row, the footer and their dividers.
    static let shortcutsChrome: CGFloat = 130

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
    static func origin(
        size: CGSize,
        visible: CGRect,
        area: CGRect? = nil
    ) -> CGPoint {
        let area = area ?? visible
        let top = visible.maxY - visible.height * topFraction
        let bottom = max(top - size.height, area.minY)
        return CGPoint(x: area.midX - size.width / 2, y: bottom)
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
