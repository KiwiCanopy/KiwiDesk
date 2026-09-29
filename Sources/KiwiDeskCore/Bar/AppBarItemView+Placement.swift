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

        /// The icon and title's span along the slot; the count
        /// badge hangs off them, sized by its own text, and is not
        /// part of it (#1779).
        var span: ClosedRange<CGFloat> {
            x...(x + side + spacing + text.width)
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

    /// The icon square in a vertical slot of `size`, centred and
    /// kept `contentPadding` off the leading end; nil where the
    /// item draws no icon.
    func verticalIconSquare(in size: CGSize) -> CGRect? {
        let pad = Self.contentPadding
        let side = iconSlotHidden ? 0 : max(contentSide(in: size) - pad * 2, 0)
        guard side > 0 else { return nil }
        return CGRect(
            x: (size.width - side) / 2,
            y: max((size.height - side) / 2, pad),
            width: side,
            height: side
        )
    }

    /// The span this item draws along a slot of `size`: its box on
    /// a boxed shelf, else its icon and title; the whole slot where it draws
    /// nothing. Reads the placements the layout draws, so it sets
    /// the label's font and text as `horizontalPlacement` does.
    func drawnSpan(in size: CGSize) -> ClosedRange<CGFloat> {
        let length = horizontal ? size.width : size.height
        guard style.shelf.drawsPlate else { return 0...length }
        if horizontal {
            let span = horizontalPlacement(in: size).span
            return span.upperBound > span.lowerBound ? span : 0...length
        }
        guard let square = verticalIconSquare(in: size) else {
            return 0...length
        }
        return square.minY...square.maxY
    }
}
