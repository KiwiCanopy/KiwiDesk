import AppKit

/// A Space item whose list a click holds open (#2571 ▸ Ruling): the
/// glyph or `+n` stays lit until its list closes, and the `+n` disc
/// reads as a window while its list shows. A group count badge keeps
/// its number.
extension SpaceBarItemView {
    /// The target whose list is open, if one of this item's is.
    var openListTarget: SpaceBarGlyphTarget? {
        targetsForHover.first { $0.actions?.peek?.holdsOpen($0) == true }
    }

    /// Whether the trailing `+n` disc's list is open.
    var overflowListOpen: Bool {
        guard let overflowTarget else { return false }
        return overflowTarget === openListTarget
    }

    static let windowSymbolID = NSUserInterfaceItemIdentifier(
        "kiwidesk.openListSymbol"
    )

    /// Draws the window symbol on `badge` in place of its count while
    /// `open`, or takes it back. An image laid on the disc, never a
    /// text attachment, which a bar font draws as nothing (device,
    /// 2026-10-24).
    static func showWindowSymbol(on badge: NSTextField, open: Bool) {
        let shown = badge.subviews.first { $0.identifier == windowSymbolID }
        guard open else {
            shown?.removeFromSuperview()
            return
        }
        let side = (min(badge.bounds.width, badge.bounds.height) * 0.62)
            .rounded()
        guard
            let image = windowSymbol(
                size: side,
                color: badge.textColor ?? .white
            )
        else { return }
        let view = shown as? NSImageView ?? NSImageView()
        view.identifier = windowSymbolID
        view.image = image
        view.imageScaling = .scaleProportionallyDown
        view.setAccessibilityElement(false)
        view.frame = CGRect(
            x: ((badge.bounds.width - side) / 2).rounded(),
            y: ((badge.bounds.height - side) / 2).rounded(),
            width: side,
            height: side
        )
        if view.superview !== badge { badge.addSubview(view) }
        badge.stringValue = ""
    }

    /// The window symbol in `color`, `size` points.
    static func windowSymbol(size: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(
            pointSize: size,
            weight: .semibold
        ).applying(.init(paletteColors: [color]))
        return NSImage(
            systemSymbolName: "macwindow",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
    }
}

/// A glyph or `+n` whose list opens or closes re-reads its item's
/// lit state (#2571).
extension SpaceBarGlyphTarget: BarPeekListAnchor {
    func listOpenChanged() {
        guard let item = superview as? SpaceBarItemView else { return }
        item.syncHoverToPointer()
        item.restyle()
    }
}
