import AppKit

/// Where a slot's content sits along it — the one reading the
/// layout draws and the shelf's section divider centres against
/// (#1779). Taken at a size handed in rather than `bounds`, which
/// is mid-glide while a render reads it.
extension AppBarItemView {
    struct HorizontalPlacement {
        /// Where the half-moon's slot starts, which leads the
        /// icon-and-title group (#2234).
        var x: CGFloat
        /// The half-moon's slot, reserved on every item.
        var moon: CGFloat
        /// Whether the half-moon draws in it: a hidden one is no
        /// drawn content (#1779).
        var moonShown: Bool
        /// The icon square's side; 0 without one.
        var side: CGFloat
        var spacing: CGFloat
        /// The title's slot (`AppBarOverlay.titleSlot`), cut to
        /// what the item has room for; zero where none draws.
        var text: CGSize
        /// The title's own fitted width, which the slot cuts
        /// (`BarTitleSlot.span`).
        var natural: CGFloat
        /// The group-count badge's reach past the title.
        var badgeExtent: CGFloat
        var showsLabel: Bool
        /// Where the icon would start were the title to fill its
        /// slot: the span reads it, so a rename moves no divider
        /// (#2643).
        var filledIconStart: CGFloat

        /// The icon and title's span along the slot, the title
        /// taken at its full slot; the count badge hangs off them,
        /// sized by its own text, and is not part of it (#1779).
        var span: ClosedRange<CGFloat> {
            let start = filledIconStart
            let end = start + side + spacing + text.width
            return (moonShown ? start - moon : start)...end
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
    /// centred by the title's drawn width between the two ends'
    /// insets, which differ where only one end is drawn rounded
    /// (#1763, #2643); the title's slot is fixed whatever it reads
    /// (#2545). Sets the label's font and text, which the
    /// measurement reads.
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
        let moon = AppBarHalfMoon.reserve(
            contentDepth: style.contentDepth(forDepth: depth)
        )
        let cell = label.cell?.cellSize ?? .zero
        var textSize = CGSize(
            width: text.isEmpty
                ? 0 : AppBarOverlay.titleSlot(style, thickness: depth),
            height: ceil(cell.height)
        )
        var spacing: CGFloat = side > 0 ? pad / 2 : 0
        let badgeReserve: CGFloat =
            count >= 2
            ? Self.badgeSide(contentSide: contentSide) + pad
            : 0
        textSize.width = min(
            textSize.width,
            size.width - moon - side - spacing - edge.total
                - badgeReserve
        )
        if textSize.width < 8 {
            textSize.width = 0
            spacing = 0
        }
        let badgeExtent: CGFloat =
            badgeReserve > 0 && textSize.width > 0
            ? badgeReserve - pad + 2
            : 0
        let natural = ceil(cell.width)
        // The icon, drawn title and badge centre; the half-moon
        // hangs before the icon, outside the centring (#2643).
        let iconStart = { (title: CGFloat) in
            max(
                (size.width - side - spacing - title - badgeExtent
                    + edge.leading - edge.trailing) / 2,
                edge.leading + moon
            )
        }
        let x = iconStart(min(natural, textSize.width)) - moon
        return HorizontalPlacement(
            x: x,
            moon: moon,
            moonShown: visibility.drawsHalfMoon,
            side: side,
            spacing: spacing,
            text: textSize,
            natural: natural,
            badgeExtent: badgeExtent,
            showsLabel: textSize.width > 0,
            filledIconStart: iconStart(textSize.width)
        )
    }

    /// The icon square in a vertical slot of `size`, centred with
    /// the half-moon's slot above it (#2234) and kept
    /// `contentPadding` off the leading end; nil where the item
    /// draws no icon.
    func verticalIconSquare(in size: CGSize) -> CGRect? {
        let pad = Self.contentPadding
        let side = iconSlotHidden ? 0 : max(contentSide(in: size) - pad * 2, 0)
        guard side > 0 else { return nil }
        let moon = AppBarHalfMoon.reserve(
            contentDepth: style.contentDepth(forDepth: size.width)
        )
        return CGRect(
            x: (size.width - side) / 2,
            y: max((size.height - side - moon) / 2, pad) + moon,
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
        let moon = visibility.drawsHalfMoon ? halfMoonFrame(in: size) : nil
        return (moon?.minY ?? square.minY)...square.maxY
    }

    /// The half-moon's disc in a slot of `size` — the one home of
    /// where it sits in its reserved slot (#2234): at the slot's
    /// start on the run, centred on the icon's cross axis; nil on a
    /// side bar item drawing no icon.
    func halfMoonFrame(in size: CGSize) -> CGRect? {
        let depth = style.contentDepth(
            forDepth: horizontal ? size.height : size.width
        )
        let diameter = AppBarHalfMoon.diameter(contentDepth: depth)
        if horizontal {
            return CGRect(
                x: horizontalPlacement(in: size).x,
                y: (size.height - diameter) / 2,
                width: diameter,
                height: diameter
            )
        }
        guard let square = verticalIconSquare(in: size) else {
            return nil
        }
        return CGRect(
            x: square.midX - diameter / 2,
            y: square.minY - AppBarHalfMoon.reserve(contentDepth: depth),
            width: diameter,
            height: diameter
        )
    }
}
