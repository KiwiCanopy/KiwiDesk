import AppKit

/// A peek taller than its room (#1946, owner ruling): it keeps the
/// windows that fit and marks the cut with a chevron and the count
/// of the rest — a button opening the menu that holds them, since
/// the peek never scrolls. The cut is at the
/// far edge from the bar, so on a bottom bar the peek keeps the
/// LAST windows and the chevron points up at the hidden ones.
extension BarPeekBody {
    /// The "more" line's parts and the width it reads at.
    struct MoreLine {
        let chevron: NSImageView
        let label: NSTextField
        let width: CGFloat
    }

    /// Lays `content` out within `maxHeight`, cutting at the top
    /// where `cutAtTop`; returns the size.
    func build(
        _ content: BarPeekContent,
        shelf: KiwiShelf,
        maxHeight: CGFloat = .greatestFiniteMagnitude,
        cutAtTop: Bool = false
    ) -> CGSize {
        let whole = layout(content, shelf: shelf, hidden: 0)
        guard whole.height > maxHeight else { return whole }
        let total = content.windowCount
        var keep = max(total - 1, 1)
        while true {
            let size = layout(
                content.keeping(keep, fromEnd: cutAtTop),
                shelf: shelf,
                hidden: total - keep,
                cutAtTop: cutAtTop
            )
            // One window at least; past that the panel clips.
            if size.height <= maxHeight || keep == 1 { return size }
            keep -= 1
        }
    }

    /// The chevron, pointing where the hidden rows are, and the
    /// count in the secondary ink. "%1$d more" counts no noun, so
    /// no locale has to agree with the number (localization.md).
    func moreLine(_ hidden: Int, shelf: KiwiShelf, up: Bool) -> MoreLine {
        let ink = NSColor(kiwiHex: shelf.idleItemColor)
        let font = shelf.textFont(ofSize: Metrics.headerSize)
        let label = Self.label(
            L("bar.peek.more", "%1$d more", hidden),
            font,
            ink
        )
        let symbol = up ? "chevron.up" : "chevron.down"
        let chevron = NSImageView()
        chevron.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            .init(pointSize: Metrics.headerSize, weight: .semibold)
        )
        chevron.contentTintColor = ink
        chevron.setAccessibilityElement(false)
        chevron.identifier = NSUserInterfaceItemIdentifier(symbol)
        let width = Metrics.chevronSide + Metrics.iconGap + Self.natural(label)
        return MoreLine(chevron: chevron, label: label, width: width)
    }

    /// Places `more` from `top`; returns where it ends.
    func place(_ more: MoreLine, at top: CGFloat, width: CGFloat) -> CGFloat {
        let inset = Metrics.chevronSide + Metrics.iconGap
        let labelWidth = max(width - inset, 1)
        let height = Self.height(of: more.label, width: labelWidth)
        let line = Self.lineHeight(more.label.font)
        more.chevron.frame = CGRect(
            x: Metrics.padH,
            y: top + (line - Metrics.chevronSide) / 2,
            width: Metrics.chevronSide,
            height: Metrics.chevronSide
        )
        more.label.frame = CGRect(
            x: Metrics.padH + inset,
            y: top,
            width: labelWidth,
            height: height
        )
        addSubview(more.chevron)
        addSubview(more.label)
        moreChevron = more.chevron
        moreLabel = more.label
        let end = top + max(height, line)
        addTarget(
            .more,
            around: CGRect(
                x: Metrics.padH,
                y: top,
                width: inset + Self.natural(more.label),
                height: end - top
            ),
            inks: [more.label, more.chevron]
        )
        return end
    }
}
