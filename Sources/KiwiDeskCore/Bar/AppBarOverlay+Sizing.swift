import AppKit

/// Layout math and slot sizing for `AppBarOverlay`.
extension AppBarOverlay {
    /// Derived slot lengths and viewport measurements along the bar axis.
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
            content: style.renderedContent,
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

    /// Measures automatic slot width across items. Measure
    /// EXACTLY as the item view draws: `.center` alignment alone
    /// widens an NSTextField cell by ~4 pt, so a raw string
    /// measurement truncates exactly the item that defined the
    /// width (QA 2026-07-19, owner 2026-07-20).
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
        let measure = NSTextField(labelWithString: "")
        measure.alignment = .center
        measure.font = font
        measure.usesSingleLineMode = true
        measure.maximumNumberOfLines = 1
        measure.lineBreakMode = .byTruncatingTail
        return items.reduce(0) { widest, item in
            let text: CGFloat
            if !style.content.showsText {
                text = 0
            } else {
                measure.stringValue = item.text
                text = ceil(
                    measure.cell?.cellSize.width ?? 0
                )
            }
            let spacing =
                iconSide > 0 && text > 0 ? pad / 2 : 0
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

    /// Shared slot length for bar layout pass.
    nonisolated static func slotLength(
        itemSize: CGFloat,
        content: AppBarStyle.Content,
        thickness: CGFloat,
        axis: CGFloat,
        autoWidth: CGFloat
    ) -> CGFloat {
        let requested = itemSize > 0 ? itemSize : autoWidth
        return max(
            min(requested, axis / 4),
            minimumSlot(thickness: thickness, content: content)
        )
    }

    /// Minimum usable slot size based on content mode. Icon
    /// slots floor at `thickness` so measurement's icon side
    /// equals layout's — the slot-fits-widest-title invariant
    /// leans on it.
    nonisolated static func minimumSlot(
        thickness: CGFloat,
        content: AppBarStyle.Content
    ) -> CGFloat {
        content == .title
            ? AppBarItemView.contentPadding * 4
            : thickness
    }

    /// Scroll offset calculation ensuring focused item remains visible.
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

    /// Computes item frames along the bar axis (#293 QA).
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
