import AppKit

/// Item sizing: every item gets the same slot length — the
/// configured `item_size`, or a standard length per content
/// mode when unset (0). The length is clamped between the
/// icon square (icons never clip) and a quarter of the bar
/// (single items never balloon). Items that overflow the
/// strip anyway don't shrink — the bar scrolls instead,
/// following the focused item (see AppBarOverlay).
/// Pure math, unit-tested.
extension AppBarOverlay {
    /// One render pass's derived lengths along the bar axis.
    /// While the items overflow the strip, the viewport they
    /// render (and clip) in is inset by the arrow zone plus
    /// one gap on both ends, so a half-scrolled item is cut
    /// a gap short of the arrow instead of sliding under it.
    struct Metrics {
        let horizontal: Bool
        let slot: CGFloat
        let gap: CGFloat
        let total: CGFloat
        let inset: CGFloat
        let viewport: CGFloat
    }

    func metrics(
        strip: CGRect,
        count: Int,
        style: AppBarStyle
    ) -> Metrics {
        let horizontal = style.position.isHorizontalEdge
        let axis = horizontal ? strip.width : strip.height
        let gap = style.itemGap
        let slot = Self.slotLength(
            itemSize: style.itemSize,
            content: style.content,
            thickness:
                horizontal ? strip.height : strip.width,
            axis: axis
        )
        let total =
            slot * CGFloat(count)
            + gap * CGFloat(max(count - 1, 0))
        let inset = total > axis ? Self.arrowZone + gap : 0
        return Metrics(
            horizontal: horizontal,
            slot: slot,
            gap: gap,
            total: total,
            inset: inset,
            viewport: max(axis - inset * 2, 0)
        )
    }

    /// Standard `item_size = 0` lengths once text is shown;
    /// icon-only items default to their square instead.
    nonisolated static let standardNameLength: CGFloat = 100
    nonisolated static let standardIconAndNameLength: CGFloat =
        140

    /// The shared slot length for one bar layout pass.
    nonisolated static func slotLength(
        itemSize: CGFloat,
        content: AppBarStyle.Content,
        thickness: CGFloat,
        axis: CGFloat
    ) -> CGFloat {
        let standard: CGFloat
        switch content {
        case .icon:
            standard = thickness
        case .name:
            standard = standardNameLength
        case .iconAndName:
            standard = standardIconAndNameLength
        }
        let requested = itemSize > 0 ? itemSize : standard
        // When the quarter cap and the icon minimum collide
        // (a tiny bar), the minimum wins: a clipped icon
        // looks worse than a bar that has to scroll.
        return max(
            min(requested, axis / 4),
            minimumSlot(thickness: thickness, content: content)
        )
    }

    /// Below this, slots stop being useful: with an icon the
    /// slot must hold its square (side = thickness − padding,
    /// plus the padding back — i.e. the thickness itself);
    /// text-only bars just keep a sliver of legibility.
    nonisolated static func minimumSlot(
        thickness: CGFloat,
        content: AppBarStyle.Content
    ) -> CGFloat {
        content == .name
            ? AppBarItemView.contentPadding * 4
            : thickness
    }

    /// The scroll offset for an overflowing bar: starts from
    /// `current` (so manual arrow scrolling sticks) and moves
    /// just far enough to keep the active slot fully visible,
    /// `margin` clear of the strip's ends (where the scroll
    /// arrows sit). Pass a nil index to only clamp. 0 while
    /// everything fits.
    nonisolated static func scrollOffset(
        current: CGFloat,
        activeIndex: Int?,
        slot: CGFloat,
        gap: CGFloat,
        count: Int,
        axis: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        let total =
            slot * CGFloat(count)
            + gap * CGFloat(max(count - 1, 0))
        guard total > axis, axis > 0 else { return 0 }
        var offset = current
        if let index = activeIndex {
            let lower = CGFloat(index) * (slot + gap)
            let upper = lower + slot
            if lower < offset + margin {
                offset = lower - margin
            }
            if upper > offset + axis - margin {
                offset = upper - axis + margin
            }
        }
        return min(max(offset, 0), total - axis)
    }

    /// Lays the lengths out along the bar axis, `gap` apart,
    /// in the container's flipped local coordinates (first
    /// item at the left / top). While everything fits the
    /// group is centered; an overflowing group starts at
    /// `-offset` instead (the scrolled-away part sticks out
    /// of the strip and is clipped).
    nonisolated static func frames(
        lengths: [CGFloat],
        in bounds: CGRect,
        gap: CGFloat,
        horizontal: Bool,
        scrolledBy offset: CGFloat = 0
    ) -> [CGRect] {
        let total =
            lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
        let axis = horizontal ? bounds.width : bounds.height
        var position =
            total > axis
            ? -offset
            : max((axis - total) / 2, 0)
        return lengths.map { length in
            defer { position += length + gap }
            return horizontal
                ? CGRect(
                    x: position,
                    y: 0,
                    width: length,
                    height: bounds.height
                )
                : CGRect(
                    x: 0,
                    y: position,
                    width: bounds.width,
                    height: length
                )
        }
    }
}
