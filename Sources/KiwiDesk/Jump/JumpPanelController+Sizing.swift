import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub's size (#1875 ▸ Panel, #3570): a fixed field row, and
/// a ceiling per side (`JumpPanelRoom`) the panel follows each
/// side's content beneath.
extension JumpPanelController {
    /// The Windows list's room, in rows: nine, the numbered reach,
    /// section headers drawn inside it (#2309).
    static let rowCap = JumpList.numbered

    /// The visible area with every KiwiShelf strip cut away by the
    /// edge Core says it sits on — the one home for where the panel
    /// may stand, read by its width, its place and the Shortcuts
    /// sheet's cap (#2246). `NSScreen.visibleFrame` leaves the shelf
    /// in. A top strip is ignored: the field stands below it at
    /// `topFraction`. A caller fitting one screen area hands that
    /// area's rect as `visible` (#3572).
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

    /// The key sequence hint panel's tallest sheet: a compact
    /// side's panel less the field and the footer row (#2246).
    static func sheetCap(visible: CGRect, area: CGRect) -> CGFloat {
        let room = room(visible: visible, area: area)
        return max(room.height(.compact) - shortcutsChrome, 200)
    }

    /// A growing side's tallest content between the field and the
    /// footer row: down to 48 pt above the area's bottom (#3570).
    static func sheetCap(in room: JumpPanelRoom) -> CGFloat {
        max(room.height(.grows) - shortcutsChrome, 200)
    }

    /// The tallest a compact side stands (#2309, #3570).
    static let maxPanelHeight = JumpPanelRoom.compactHeight

    /// What the Shortcuts side draws besides its sheet: the field,
    /// the footer row and their two dividers.
    static var shortcutsChrome: CGFloat {
        JumpPanelView.fieldHeight + 2
            + JumpFooterRow<EmptyView, EmptyView>.height(
                carriesControls: true
            )
    }

    /// Where the panel's top — its field — sits: Spotlight's, so
    /// the field lands where a search field is looked for and the
    /// list grows down from it (#2229). Measured on macOS 27:
    /// Spotlight's field top 278 pt below the visible area's top
    /// of 1083 pt, on a 1728×1117 screen. One screen size, so
    /// whether it scales or holds a fixed offset is unmeasured.
    static let topFraction: CGFloat = 0.257

    /// The room the panel fits on `visible`, cut to `area`.
    static func room(visible: CGRect, area: CGRect) -> JumpPanelRoom {
        JumpPanelRoom(visible: visible, area: area, topFraction: topFraction)
    }

    /// Fits the panel to its side, holding its centre across and
    /// its top, so the field row never moves; a side switch glides
    /// the outer edges there (#2229, #3570), at once under Reduce
    /// Motion.
    func refit(animated: Bool = false) {
        guard let panel, panel.isVisible,
            let content = panel.contentView
        else { return }
        content.layoutSubtreeIfNeeded()
        let frame = JumpPanelRoom.refitted(
            panel.frame,
            to: content.fittingSize
        )
        panel.setFrame(
            frame,
            display: true,
            animate: animated && !presence.reduceMotion
        )
    }

    /// Each app's icon, read once per opening.
    static func icons(
        for snapshot: JumpSnapshot
    ) -> [pid_t: NSImage] {
        icons(for: Set(snapshot.entries.map(\.pid) + snapshot.apps.map(\.pid)))
    }

    static func icons(for pids: Set<pid_t>) -> [pid_t: NSImage] {
        var icons: [pid_t: NSImage] = [:]
        for pid in pids {
            icons[pid] =
                NSRunningApplication(processIdentifier: pid)?.icon
        }
        return icons
    }
}
