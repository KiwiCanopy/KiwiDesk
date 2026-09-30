import AppKit

/// The break between the tiled row and its floats (#1826) — the
/// Space Bar layer break's tier (#1169), after the last tiled
/// item. It rides the run: that item's slot is widened by the rule
/// and a gap, so scrolling, hugging and the plate measure it.
extension AppBarOverlay {
    /// The last tiled item when floats follow it; nil when either
    /// side is empty, which draws no break.
    nonisolated static func breakAfter(_ items: [Item]) -> Int? {
        guard let first = items.firstIndex(where: \.floating), first > 0
        else { return nil }
        return first - 1
    }

    /// The tiled items — the ones a drag reorders.
    nonisolated static func tiledCount(_ items: [Item]) -> Int {
        items.firstIndex(where: \.floating) ?? items.count
    }

    /// Axis length the rule adds to the break's slot.
    nonisolated static func floatBreakExtent(gap: CGFloat) -> CGFloat {
        gap + BarDivider.sectionThickness
    }

    /// Every slot at `slot`, the break's widened by the rule.
    nonisolated static func lengths(
        slot: CGFloat,
        count: Int,
        gap: CGFloat,
        breakAfter: Int?
    ) -> [CGFloat] {
        var lengths = Array(repeating: slot, count: count)
        if let index = breakAfter, lengths.indices.contains(index) {
            lengths[index] += floatBreakExtent(gap: gap)
        }
        return lengths
    }

    /// `slots` with the break's trimmed back to the item's own
    /// length — the frames the views take.
    nonisolated static func itemFrames(
        _ slots: [CGRect],
        m: Metrics
    ) -> [CGRect] {
        guard let index = m.breakAfter, slots.indices.contains(index)
        else { return slots }
        var frames = slots
        if m.horizontal {
            frames[index].size.width = m.slot
        } else {
            frames[index].size.height = m.slot
        }
        return frames
    }

    /// Lays the rule out after the break's item, or hides it when
    /// no break is drawn. Returns the frames the views take.
    func layoutFloatBreak(
        slots: [CGRect],
        m: Metrics,
        depth: CGFloat,
        style: AppBarLook
    ) -> [CGRect] {
        let frames = Self.itemFrames(slots, m: m)
        guard let index = m.breakAfter, frames.indices.contains(index)
        else {
            floatDivider.isHidden = true
            return frames
        }
        let item = frames[index]
        floatDivider.isHidden = false
        floatDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor).cgColor
        floatDivider.frame = BarDivider.frame(
            at: (m.horizontal ? item.maxX : item.maxY) + m.gap,
            depth: depth,
            horizontal: m.horizontal,
            thickness: BarDivider.sectionThickness,
            lengthShare: BarDivider.sectionLengthShare
        )
        return frames
    }
}
