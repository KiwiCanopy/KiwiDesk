import AppKit

/// Where a slot's content sits along it — the one reading the
/// layout draws and the shelf's section divider centres against
/// (#1779). Taken at a size handed in rather than `bounds`, which
/// is mid-glide while a render reads it.
extension AppBarItemView {
    struct HorizontalPlacement {
        /// Where the icon-and-title group starts.
        var x: CGFloat
        /// The icon square's side; 0 without one.
        var side: CGFloat
        var spacing: CGFloat
        var text: CGSize
        /// The group-count badge's reach past the title.
        var badgeExtent: CGFloat
        var showsLabel: Bool

        /// The group's span along the slot.
        var span: ClosedRange<CGFloat> {
            x...(x + side + spacing + text.width + badgeExtent)
        }
    }

    /// The content square's side in a slot of `size`.
    func contentSide(in size: CGSize) -> CGFloat {
        min(
            style.contentDepth(
                forDepth: horizontal ? size.height : size.width
            ),
            horizontal ? size.width : size.height
        )
    }

    /// The icon-and-title group in a horizontal slot of `size`,
    /// centred between the two ends' insets, which differ where
    /// only one end is drawn rounded (#1763). Sets the label's
    /// font and text, which the measurement reads.
    func horizontalPlacement(in size: CGSize) -> HorizontalPlacement {
        let pad = Self.contentPadding
        let depth = size.height
        let contentSide = contentSide(in: size)
        let edge = Self.endPadding(
            style,
            depth: depth,
            first: isFirstInRun,
            last: isLastInRun
        )
        label.font = style.shelf.textFont(
            ofSize: style.resolvedFontSize(forDepth: depth)
        )
        // Not `usesSingleLineMode`: it draws a tall face above its
        // own ascent, clipping the title (#1707).
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.stringValue = text
        let side = iconSlotHidden ? 0 : max(contentSide - pad * 2, 0)
        let showText = style.content.showsText
        var textSize = showText ? (label.cell?.cellSize ?? .zero) : .zero
        textSize.width = ceil(textSize.width)
        textSize.height = ceil(textSize.height)
        var spacing: CGFloat = side > 0 && showText ? pad / 2 : 0
        let badgeReserve: CGFloat =
            count >= 2 && showText
            ? Self.badgeSide(contentSide: contentSide) + pad
            : 0
        textSize.width = min(
            textSize.width,
            size.width - side - spacing - edge.total - badgeReserve
        )
        if textSize.width < 8 {
            textSize.width = 0
            spacing = 0
        }
        let badgeExtent: CGFloat =
            badgeReserve > 0 && textSize.width > 0
            ? badgeReserve - pad + 2
            : 0
        let x = max(
            (size.width - side - spacing - textSize.width
                - badgeExtent + edge.leading - edge.trailing) / 2,
            showText ? edge.leading : pad
        )
        return HorizontalPlacement(
            x: x,
            side: side,
            spacing: spacing,
            text: textSize,
            badgeExtent: badgeExtent,
            showsLabel: showText && textSize.width > 0
        )
    }

    /// The span this item draws along a slot of `size`: its box on
    /// a boxed shelf, else its content group — the vertical icon
    /// centred as `layoutVertical` places it; the whole slot where
    /// it draws nothing.
    func drawnSpan(in size: CGSize) -> ClosedRange<CGFloat> {
        let length = horizontal ? size.width : size.height
        guard style.shelf.drawsPlate else { return 0...length }
        if horizontal {
            let span = horizontalPlacement(in: size).span
            return span.upperBound > span.lowerBound ? span : 0...length
        }
        let side =
            iconSlotHidden
            ? 0 : max(contentSide(in: size) - Self.contentPadding * 2, 0)
        guard side > 0 else { return 0...length }
        let start = max((length - side) / 2, Self.contentPadding)
        return start...(start + side)
    }
}
