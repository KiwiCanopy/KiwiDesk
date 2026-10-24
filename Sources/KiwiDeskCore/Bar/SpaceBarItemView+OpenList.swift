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

    /// The `+n` disc's text while its list is open: the window
    /// symbol in the badge's own ink and size.
    static func windowSymbol(
        size: CGFloat,
        color: NSColor
    ) -> NSAttributedString? {
        let config = NSImage.SymbolConfiguration(
            pointSize: size,
            weight: .semibold
        ).applying(.init(paletteColors: [color]))
        guard
            let image = NSImage(
                systemSymbolName: "macwindow",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
        else { return nil }
        let attachment = NSTextAttachment()
        attachment.image = image
        let text = NSMutableAttributedString(attachment: attachment)
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        text.addAttribute(
            .paragraphStyle,
            value: centred,
            range: NSRange(location: 0, length: text.length)
        )
        return text
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
