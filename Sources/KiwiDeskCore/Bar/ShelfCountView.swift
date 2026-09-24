import AppKit

/// How many entries a shelf section hides on one side, drawn on
/// that side's faded end (#1517) — `‹ 3` before, `4 ›` after, the
/// chevron an SF Symbol at the digits' size and weight, stacked on
/// a vertical shelf. The chevron stays: a bare number beside a
/// glyph reads as its badge. A click pages that way; VoiceOver
/// hears a button that does the same.
@MainActor
final class ShelfCountView: NSView {
    enum Side { case before, after }

    var onPage: () -> Void = {}
    let side: Side
    private let label = NSTextField(labelWithString: "")
    private let chevron = NSImageView()
    private var horizontal = true
    private var count = 0
    private var isDragHovered = false
    private var ink: NSColor = .labelColor
    private var hoverInk: NSColor = .labelColor

    init(side: Side) {
        self.side = side
        super.init(frame: .zero)
        wantsLayer = true
        isHidden = true
        label.alignment = .center
        label.setAccessibilityElement(false)
        chevron.setAccessibilityElement(false)
        chevron.imageScaling = .scaleNone
        addSubview(label)
        addSubview(chevron)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ShelfCountView is code-only")
    }

    /// Shows `count` hidden entries, or hides the view at zero —
    /// a side at its end shows nothing.
    func configure(
        count: Int,
        horizontal: Bool,
        fontSize: CGFloat,
        ink: NSColor,
        hoverInk: NSColor
    ) {
        self.count = count
        self.ink = ink
        self.hoverInk = hoverInk
        self.horizontal = horizontal
        isHidden = count == 0
        guard count > 0 else { return }
        label.stringValue = "\(count)"
        label.font = .systemFont(ofSize: fontSize, weight: .semibold)
        let glyph = Self.glyph(side: side, horizontal: horizontal)
        chevron.image = NSImage(
            systemSymbolName: glyph.symbol,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: fontSize,
                weight: .semibold,
                scale: .small
            )
        )
        applyInk()
        setAccessibilityLabel(
            side == .before
                ? L("kiwishelf.count.before.ax", "More before: %1$d", count)
                : L("kiwishelf.count.after.ax", "More after: %1$d", count)
        )
        needsLayout = true
    }

    /// The chevron pointing where the hidden entries are, and
    /// whether it leads the number — it sits on the side away
    /// from the content: left or above before, right or below
    /// after.
    nonisolated static func glyph(
        side: Side,
        horizontal: Bool
    ) -> (symbol: String, leads: Bool) {
        switch (side, horizontal) {
        case (.before, true): return ("chevron.left", true)
        case (.after, true): return ("chevron.right", false)
        case (.before, false): return ("chevron.up", true)
        case (.after, false): return ("chevron.down", false)
        }
    }

    /// Between the chevron and the number.
    nonisolated static let partGap: CGFloat = 2

    /// The width or height this view needs along the shelf.
    var fittingLength: CGFloat {
        label.sizeToFit()
        let glyph = chevron.image?.size ?? .zero
        return horizontal
            ? label.frame.width + Self.partGap + glyph.width + 8
            : label.frame.height + Self.partGap + glyph.height + 4
    }

    /// Sits this count on its fading end of `container` — the one
    /// placement both sections take.
    func place(in container: CGRect, atEnd: Bool) {
        guard !isHidden else { return }
        let length = fittingLength
        frame =
            horizontal
            ? CGRect(
                x: atEnd ? container.maxX - length : container.minX,
                y: container.minY,
                width: length,
                height: container.height
            )
            : CGRect(
                x: container.minX,
                y: atEnd ? container.maxY - length : container.minY,
                width: container.width,
                height: length
            )
    }

    /// Synthetic hover while a dragged window rests on this end.
    func setDragHover(_ hovered: Bool) {
        guard isDragHovered != hovered else { return }
        isDragHovered = hovered
        applyInk()
    }

    override func mouseDown(with event: NSEvent) {
        onPage()
    }

    override func accessibilityPerformPress() -> Bool {
        onPage()
        return true
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        label.sizeToFit()
        let number = label.frame.size
        let glyph = chevron.image?.size ?? .zero
        let leads = Self.glyph(side: side, horizontal: horizontal).leads
        if horizontal {
            let run = number.width + Self.partGap + glyph.width
            let start = (bounds.width - run) / 2
            let numberX = leads ? start + glyph.width + Self.partGap : start
            let glyphX = leads ? start : start + number.width + Self.partGap
            label.frame.origin = CGPoint(
                x: numberX,
                y: (bounds.height - number.height) / 2
            )
            chevron.frame = CGRect(
                x: glyphX,
                y: (bounds.height - glyph.height) / 2,
                width: glyph.width,
                height: glyph.height
            )
        } else {
            let run = number.height + Self.partGap + glyph.height
            let start = (bounds.height - run) / 2
            let numberY = leads ? start + glyph.height + Self.partGap : start
            let glyphY = leads ? start : start + number.height + Self.partGap
            label.frame.origin = CGPoint(
                x: (bounds.width - number.width) / 2,
                y: numberY
            )
            chevron.frame = CGRect(
                x: (bounds.width - glyph.width) / 2,
                y: glyphY,
                width: glyph.width,
                height: glyph.height
            )
        }
    }

    private func applyInk() {
        let color = isDragHovered ? hoverInk : ink
        label.textColor = color
        chevron.contentTintColor = color
    }
}
