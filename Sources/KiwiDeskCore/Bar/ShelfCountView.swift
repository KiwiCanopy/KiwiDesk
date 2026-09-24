import AppKit

/// How many entries a shelf section hides on one side, drawn on
/// that side's faded end (#1517) — `‹3` before, `4›` after. The
/// chevron stays: a bare number beside a glyph reads as its badge.
/// A click pages that way; VoiceOver hears a button that does the
/// same.
@MainActor
final class ShelfCountView: NSView {
    enum Side { case before, after }

    var onPage: () -> Void = {}
    let side: Side
    private let label = NSTextField(labelWithString: "")
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
        addSubview(label)
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
        isHidden = count == 0
        guard count > 0 else { return }
        label.stringValue = Self.text(
            count: count,
            side: side,
            horizontal: horizontal
        )
        label.font = .systemFont(ofSize: fontSize, weight: .semibold)
        applyInk()
        setAccessibilityLabel(
            side == .before
                ? L("kiwishelf.count.before.ax", "More before: %1$d", count)
                : L("kiwishelf.count.after.ax", "More after: %1$d", count)
        )
        needsLayout = true
    }

    /// The drawn text: a chevron pointing where the entries are,
    /// on the side away from the content.
    nonisolated static func text(
        count: Int,
        side: Side,
        horizontal: Bool
    ) -> String {
        switch (side, horizontal) {
        case (.before, true): return "‹\(count)"
        case (.after, true): return "\(count)›"
        case (.before, false): return "˄\(count)"
        case (.after, false): return "\(count)˅"
        }
    }

    /// The width or height this view needs along the shelf.
    var fittingLength: CGFloat {
        label.sizeToFit()
        return label.frame.width + 8
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

    override func layout() {
        super.layout()
        label.sizeToFit()
        label.frame.origin = CGPoint(
            x: (bounds.width - label.frame.width) / 2,
            y: (bounds.height - label.frame.height) / 2
        )
    }

    private func applyInk() {
        label.textColor = isDragHovered ? hoverInk : ink
    }
}
