import AppKit

/// The floating mark between the tiled row and its floats (#1826):
/// one idle-ink `FloatingStyle` symbol after the last tiled item,
/// a section marker rather than a per-item badge. It rides the
/// run: that item's slot is widened by the mark and a gap, so
/// scrolling, hugging and the plate measure it.
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

    /// The mark's side, on the title's size ladder so it scales
    /// with the glyph size (#1682).
    nonisolated static func floatMarkSide(
        style: AppBarLook,
        depth: CGFloat
    ) -> CGFloat {
        style.resolvedFontSize(forDepth: depth)
    }

    /// Axis length the mark adds to the break's slot.
    nonisolated static func floatBreakExtent(
        gap: CGFloat,
        style: AppBarLook,
        depth: CGFloat
    ) -> CGFloat {
        gap + floatMarkSide(style: style, depth: depth)
    }

    /// Every slot at `slot`, the break's widened by `extent`.
    nonisolated static func lengths(
        slot: CGFloat,
        count: Int,
        breakAfter: Int?,
        extent: CGFloat
    ) -> [CGFloat] {
        var lengths = Array(repeating: slot, count: count)
        if let index = breakAfter, lengths.indices.contains(index) {
            lengths[index] += extent
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

    /// Lays the mark out after the break's item, or hides it when
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
            floatMark.isHidden = true
            return frames
        }
        let item = frames[index]
        let side = Self.floatMarkSide(style: style, depth: depth)
        let start = (m.horizontal ? item.maxX : item.maxY) + m.gap
        let across = (depth - side) / 2
        floatMark.isHidden = false
        floatMark.contentTintColor = NSColor(
            kiwiHex: style.shelf.idleItemColor
        )
        floatMark.frame =
            m.horizontal
            ? CGRect(x: start, y: across, width: side, height: side)
            : CGRect(x: across, y: start, width: side, height: side)
        return frames
    }
}

/// The floating mark's view: the shared symbol, inert to the pointer
/// and silent to VoiceOver, which hears "floating" on each item.
final class FloatBreakMark: NSImageView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        image = NSImage(
            systemSymbolName: FloatingStyle.symbolName,
            accessibilityDescription: nil
        )
        imageScaling = .scaleProportionallyUpOrDown
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FloatBreakMark is code-only")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
