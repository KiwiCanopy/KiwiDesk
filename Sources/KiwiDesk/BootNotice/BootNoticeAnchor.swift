import AppKit

/// Where the slow-boot notice sits (#1715), in AppKit screen
/// coordinates (y up): under KiwiDesk's menu-bar item where that
/// item is visible, else top-centre below the menu bar — under
/// the notch where there is one (owner ruling 2026-10-07). Pure
/// so a test places it without a screen.
enum BootNoticeAnchor {
    /// Below the menu bar's bottom edge.
    static let gap: CGFloat = 6
    /// The least distance from a screen edge.
    static let inset: CGFloat = 8

    /// The notice's origin for `size` on `screen`, `menuBar` tall,
    /// centred on `item` when one is given.
    static func origin(
        size: CGSize,
        screen: CGRect,
        menuBar: CGFloat,
        item: CGRect?
    ) -> CGPoint {
        let x =
            item.map { $0.midX - size.width / 2 }
            ?? screen.midX - size.width / 2
        let clamped = min(
            max(x, screen.minX + inset),
            screen.maxX - inset - size.width
        )
        return CGPoint(
            x: clamped,
            y: screen.maxY - menuBar - gap - size.height
        )
    }

    /// Whether the item's frame can anchor the notice: on its
    /// screen and clear of the notch's gap, where macOS parks an
    /// item it has no room for.
    static func anchors(
        item: CGRect,
        screen: CGRect,
        notchGap: ClosedRange<CGFloat>?
    ) -> Bool {
        guard screen.contains(item) else { return false }
        guard let notchGap else { return true }
        return item.maxX <= notchGap.lowerBound
            || item.minX >= notchGap.upperBound
    }

    /// The gap between a notched screen's two menu-bar areas.
    static func notchGap(of screen: NSScreen) -> ClosedRange<CGFloat>? {
        guard let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea,
            left.maxX < right.minX
        else { return nil }
        return left.maxX...right.minX
    }

    /// The menu bar's height on `screen`, shown or auto-hidden, so
    /// the notice does not jump when a hidden bar slides down.
    @MainActor
    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        max(
            screen.safeAreaInsets.top,
            NSApp.mainMenu?.menuBarHeight ?? 0,
            24
        )
    }
}
