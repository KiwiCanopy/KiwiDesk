import AppKit

/// The break between the tiled row and its floats (#1826): a rule
/// at the in-item rule tier ends the row, and one idle-ink
/// `FloatingStyle` symbol opens the float section — a section
/// marker, not a per-item badge. It rides the run: the last tiled
/// item's slot is widened by both and their gaps, so scrolling,
/// hugging and the plate measure it.
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

    /// Axis length the break adds to the last tiled slot: gap,
    /// rule, gap, mark.
    nonisolated static func floatBreakExtent(
        gap: CGFloat,
        style: AppBarLook,
        depth: CGFloat
    ) -> CGFloat {
        gap * 2 + BarDivider.ruleThickness
            + floatMarkSide(style: style, depth: depth)
    }

    /// Each item's slot length at `slot`, the break's widened by
    /// the break — the one derivation the render's `Metrics` and
    /// the shelf's `naturalLength` share.
    nonisolated static func lengths(
        items: [Item],
        slot: CGFloat,
        style: AppBarLook,
        thickness: CGFloat
    ) -> [CGFloat] {
        var lengths = Array(repeating: slot, count: items.count)
        if let index = breakAfter(items) {
            lengths[index] += floatBreakExtent(
                gap: style.itemGap,
                style: style,
                depth: thickness
            )
        }
        return lengths
    }

    /// The frames the item views take in `bounds`: the run's slots,
    /// the break's trimmed back to the item's own length.
    nonisolated static func itemFrames(
        in bounds: CGRect,
        m: Metrics
    ) -> [CGRect] {
        var frames = Self.frames(
            lengths: m.lengths,
            in: bounds,
            gap: m.gap,
            horizontal: m.horizontal,
            alignment: m.alignment
        )
        guard let index = m.breakAfter, frames.indices.contains(index)
        else { return frames }
        if m.horizontal {
            frames[index].size.width = m.slot
        } else {
            frames[index].size.height = m.slot
        }
        return frames
    }

    /// Lays the rule and the mark out after the break's item —
    /// inside the render's `BarMotion.runLayout` pass, so they
    /// travel with the items — or hides them when no break is
    /// drawn.
    func layoutFloatBreak(
        frames: [CGRect],
        m: Metrics,
        depth: CGFloat,
        style: AppBarLook
    ) {
        guard let index = m.breakAfter, frames.indices.contains(index)
        else {
            floatRule.isHidden = true
            floatMark.isHidden = true
            return
        }
        let item = frames[index]
        let side = Self.floatMarkSide(style: style, depth: depth)
        let ruleAt = (m.horizontal ? item.maxX : item.maxY) + m.gap
        floatRule.isHidden = false
        floatRule.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor).cgColor
        BarMotion.setFrame(
            floatRule,
            to: BarDivider.frame(
                at: ruleAt,
                depth: depth,
                horizontal: m.horizontal
            ),
            animated: true
        )
        let start = ruleAt + BarDivider.ruleThickness + m.gap
        let across = (depth - side) / 2
        floatMark.isHidden = false
        floatMark.contentTintColor = NSColor(
            kiwiHex: style.shelf.idleItemColor
        )
        BarMotion.setFrame(
            floatMark,
            to: m.horizontal
                ? CGRect(x: start, y: across, width: side, height: side)
                : CGRect(x: across, y: start, width: side, height: side),
            animated: true
        )
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

/// The break's rule: a boundary, not a state, so it is inert and
/// keeps its ink whatever is focused.
final class FloatBreakRule: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FloatBreakRule is code-only")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
