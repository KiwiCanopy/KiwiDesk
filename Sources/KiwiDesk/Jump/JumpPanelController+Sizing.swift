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

    /// The tallest sheet between the field and the footer row on a
    /// `fit` side: a compact side's 488 pt ceiling, or a growing
    /// side's run to 48 pt above the area's bottom (#2246, #3570).
    static func sheetCap(
        in room: JumpPanelRoom,
        _ fit: JumpPanelRoom.Fit
    ) -> CGFloat {
        max(room.height(fit) - shortcutsChrome, 200)
    }

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

    /// The visible frame assumed when no screen is under the pointer.
    static let fallbackVisible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    /// The room the panel fits on `visible`, cut to `area`.
    static func room(visible: CGRect, area: CGRect) -> JumpPanelRoom {
        JumpPanelRoom(visible: visible, area: area, topFraction: topFraction)
    }

    /// Fits the panel to its side around `anchor`, the field row's
    /// centre and top as the opening placed them, so the field row
    /// never moves whatever AppKit did to the frame meanwhile; a
    /// side switch glides the outer edges there (#2229, #3570), at
    /// once under Reduce Motion.
    func refit(animated: Bool = false) {
        guard let panel, panel.isVisible,
            let content = panel.contentView
        else { return }
        content.layoutSubtreeIfNeeded()
        let frame = JumpPanelRoom.frame(
            of: content.fittingSize,
            under: anchor
        )
        guard animated, !presence.reduceMotion else {
            panel.setFrame(frame, display: true)
            return
        }
        // The animator glides without blocking the run loop, so a
        // keystroke's glide never holds the next one (#3570).
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.glide
            panel.animator().setFrame(frame, display: true)
        }
    }

    /// A refit's glide, in seconds.
    static let glide: TimeInterval = 0.18

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
