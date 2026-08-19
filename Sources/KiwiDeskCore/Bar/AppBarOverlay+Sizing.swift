import AppKit

/// Box sizing: every item gets the same slot length — the
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
        let alignment: AppBarStyle.BarAlignment
    }

    func metrics(
        strip: CGRect,
        count: Int,
        style: AppBarStyle,
        items: [Item]
    ) -> Metrics {
        let horizontal = style.edge.isHorizontal
        let axis = horizontal ? strip.width : strip.height
        let thickness = horizontal ? strip.height : strip.width
        let gap = style.itemGap
        let slot = Self.slotLength(
            itemSize: style.itemSize,
            content: style.content.rendered(
                horizontal: horizontal
            ),
            thickness: thickness,
            axis: axis,
            autoWidth: Self.autoSlotWidth(
                items: items,
                style: style,
                horizontal: horizontal,
                thickness: thickness
            )
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
            viewport: max(axis - inset * 2, 0),
            alignment: style.alignment
        )
    }

    /// The auto (`item_size = 0`) slot length: on a horizontal
    /// bar, the widest item measured at the effective font (so
    /// slots fit their real names instead of a fixed guess); a
    /// vertical bar renders icon-only (QA 2026-07-19), so its
    /// slot is the icon square — the thickness. The caller
    /// still clamps this between the icon minimum and a quarter
    /// of the bar in `slotLength`.
    @MainActor
    static func autoSlotWidth(
        items: [Item],
        style: AppBarStyle,
        horizontal: Bool,
        thickness: CGFloat
    ) -> CGFloat {
        guard horizontal else { return thickness }
        let pad = AppBarItemView.contentPadding
        let font = NSFont.systemFont(
            ofSize: style.resolvedFontSize(
                forThickness: thickness
            )
        )
        let iconSide =
            style.content == .title
            ? 0 : max(thickness - pad * 2, 0)
        // The uniform slot fits the widest item, so measure every
        // name and take the max: icon square + gap + text + pads,
        // mirroring `layoutHorizontal`'s own composition. Measure
        // through a label configured EXACTLY like the item's own —
        // notably `.center` alignment, which alone widens the cell
        // by 4 pt; a left-aligned or raw-string measurement leaves
        // the widest name's slot those 4 pt short of itself,
        // tail-truncating exactly the item that defined the width.
        let measure = NSTextField(labelWithString: "")
        measure.alignment = .center
        measure.font = font
        measure.usesSingleLineMode = true
        measure.maximumNumberOfLines = 1
        measure.lineBreakMode = .byTruncatingTail
        return items.reduce(0) { widest, item in
            let text: CGFloat
            if style.content == .icon {
                text = 0
            } else {
                measure.stringValue = item.text
                text = ceil(
                    measure.cell?.cellSize.width ?? 0
                )
            }
            let spacing =
                iconSide > 0 && text > 0 ? pad / 2 : 0
            // A grouped item's count badge sits after the name, so
            // the slot must be wide enough for it too or the widest
            // name over-truncates (owner 2026-07-20) — same reserve
            // as `layoutHorizontal`.
            let badge =
                item.count >= 2 && text > 0
                ? min(max(thickness * 0.32, 9), 14) + pad
                : 0
            let natural =
                iconSide + spacing + text + badge
                + AppBarItemView.edgePadding * 2
            return max(widest, natural)
        }
    }

    /// The shared slot length for one bar layout pass. `autoWidth`
    /// is the measured/standard length used when `item_size` is 0.
    nonisolated static func slotLength(
        itemSize: CGFloat,
        content: AppBarStyle.Content,
        thickness: CGFloat,
        axis: CGFloat,
        autoWidth: CGFloat
    ) -> CGFloat {
        let requested = itemSize > 0 ? itemSize : autoWidth
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
    /// Load-bearing beyond looks: icon-bearing slots flooring
    /// at `thickness` is what makes the measurement's
    /// `iconSide = thickness - pad*2` equal the layout's
    /// `min(bounds.height, bounds.width) - pad*2` — the
    /// slot-fits-widest-name invariant leans on it.
    nonisolated static func minimumSlot(
        thickness: CGFloat,
        content: AppBarStyle.Content
    ) -> CGFloat {
        content == .title
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
    /// group sits per `alignment` (start/center/end, edge-
    /// relative); an overflowing group starts at `-offset`
    /// regardless — once the group scrolls, the three
    /// alignments collapse to one visual (#293 QA, plan Q1).
    nonisolated static func frames(
        lengths: [CGFloat],
        in bounds: CGRect,
        gap: CGFloat,
        horizontal: Bool,
        alignment: AppBarStyle.BarAlignment,
        scrolledBy offset: CGFloat = 0
    ) -> [CGRect] {
        let total =
            lengths.reduce(0, +)
            + gap * CGFloat(max(lengths.count - 1, 0))
        let axis = horizontal ? bounds.width : bounds.height
        var position: CGFloat
        if total > axis {
            position = -offset
        } else {
            switch alignment {
            case .start: position = 0
            case .center: position = (axis - total) / 2
            case .end: position = axis - total
            }
        }
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
