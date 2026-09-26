import AppKit

/// How many entries a shelf section hides on one side, drawn on
/// that side's faded end (#1517): the number and an SF Symbol
/// chevron pointing where the entries are — stacked, number on
/// top, on a horizontal shelf; side by side, number first, on a
/// vertical one (owner 2026-09-25). The chevron stays: a bare
/// number beside a glyph reads as its badge. A click pages that
/// way; VoiceOver hears a button that does the same.
@MainActor
final class ShelfCountView: NSView {
    enum Side { case before, after }

    var onPage: () -> Void = {}
    let side: Side
    /// The hover chip — the Space items' hover fill, only under
    /// the pointer, so the count reads as clickable (ui-designer).
    private let chip = NSView()
    private var chipRadius: CGFloat = 0
    private let label = NSTextField(labelWithString: "")
    private let chevron = NSImageView()
    private var horizontal = true
    private var count = 0
    private var fontSize: CGFloat = 12
    /// The SF Symbol `configure` drew, for the placement guard.
    private(set) var drawnSymbol: String?
    private(set) var isHovered = false
    private var isDragHovered = false
    private var ink: NSColor = .labelColor
    private var hoverInk: NSColor = .labelColor

    /// The number's size against the shelf's depth, and the
    /// chevron's against the number's: the stack fits a 24 pt
    /// shelf with margin (ui-designer, #1517).
    nonisolated static let numberDepthShare: CGFloat = 0.42
    nonisolated static let chevronShare: CGFloat = 0.7
    /// Between the number and the chevron, stacked and side by side.
    nonisolated static let stackGap: CGFloat = 1
    nonisolated static let sideGap: CGFloat = 2
    /// The chip's inset from the shelf's depth (a Space item
    /// cell's) and its padding around the count along the shelf.
    nonisolated static let chipInset: CGFloat = 4
    nonisolated static let chipPad: CGFloat = 4

    init(side: Side) {
        self.side = side
        super.init(frame: .zero)
        wantsLayer = true
        isHidden = true
        label.alignment = .center
        label.setAccessibilityElement(false)
        chevron.setAccessibilityElement(false)
        chevron.imageScaling = .scaleNone
        chip.wantsLayer = true
        chip.isHidden = true
        addSubview(chip)
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
    /// a side at its end shows nothing. The size is settled by
    /// `place(in:atEnd:)`, which knows the shelf's depth.
    func configure(
        count: Int,
        horizontal: Bool,
        fontSize: CGFloat,
        ink: NSColor,
        hoverInk: NSColor,
        hoverFill: NSColor = .clear,
        chipRadius: CGFloat = 0
    ) {
        chip.layer?.backgroundColor = hoverFill.cgColor
        self.chipRadius = chipRadius
        self.count = count
        self.ink = ink
        self.hoverInk = hoverInk
        self.horizontal = horizontal
        self.fontSize = fontSize
        isHidden = count == 0
        guard count > 0 else { return }
        label.stringValue = "\(count)"
        drawnSymbol = Self.symbol(side: side, horizontal: horizontal)
        applyInk()
        setAccessibilityLabel(
            side == .before
                ? L("kiwishelf.count.before.ax", "More before: %1$d", count)
                : L("kiwishelf.count.after.ax", "More after: %1$d", count)
        )
        needsLayout = true
    }

    /// The chevron pointing where the hidden entries are.
    nonisolated static func symbol(side: Side, horizontal: Bool) -> String {
        switch (side, horizontal) {
        case (.before, true): return "chevron.left"
        case (.after, true): return "chevron.right"
        case (.before, false): return "chevron.up"
        case (.after, false): return "chevron.down"
        }
    }

    /// Whether the number and chevron stack (a horizontal shelf)
    /// rather than sit side by side.
    var stacks: Bool { horizontal }

    /// Sizes the number and chevron for a shelf `depth` deep.
    private func applyFonts(depth: CGFloat) {
        let size = min(fontSize, depth * Self.numberDepthShare)
        label.font = .systemFont(ofSize: size, weight: .semibold)
        chevron.image = drawnSymbol.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)
        }?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(
                pointSize: size * Self.chevronShare,
                weight: .semibold,
                scale: .small
            )
        )
        label.sizeToFit()
    }

    /// The digits' own extent: a label's frame carries its cell's
    /// padding (~8 pt), which a 24 pt side-by-side count cannot
    /// spare.
    private var numberSize: CGSize {
        label.attributedStringValue.size()
    }

    /// The width or height this view needs along the shelf.
    var fittingLength: CGFloat {
        let number = numberSize
        let glyph = chevron.image?.size ?? .zero
        return stacks
            ? max(number.width, glyph.width) + 2 * Self.chipPad + 8
            : max(number.height, glyph.height) + 2 * Self.chipPad + 4
    }

    /// Sits this count on its fading end of `container` — the one
    /// placement both sections take.
    func place(in container: CGRect, atEnd: Bool) {
        guard !isHidden else { return }
        applyFonts(depth: horizontal ? container.height : container.width)
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
        needsLayout = true
    }

    /// Synthetic hover while a dragged window rests on this end.
    func setDragHover(_ hovered: Bool) {
        guard isDragHovered != hovered else { return }
        isDragHovered = hovered
        applyInk()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        // `.activeAlways`: the shelf's panel never becomes key.
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [
                    .mouseEnteredAndExited, .activeAlways, .inVisibleRect,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }
    override func mouseExited(with event: NSEvent) { setHovered(false) }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        applyInk()
    }

    /// Re-reads the hover from where the pointer rests (#1665).
    func syncHoverToPointer() {
        setHovered(BarHoverHit.ownsPointer(self))
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
        let number = numberSize
        let glyph = chevron.image?.size ?? .zero
        let numberCenter: CGPoint
        if stacks {
            let run = number.height + Self.stackGap + glyph.height
            let top = (bounds.height - run) / 2
            numberCenter = CGPoint(x: bounds.midX, y: top + number.height / 2)
            chevron.frame = CGRect(
                x: (bounds.width - glyph.width) / 2,
                y: top + number.height + Self.stackGap,
                width: glyph.width,
                height: glyph.height
            )
        } else {
            let run = number.width + Self.sideGap + glyph.width
            let lead = (bounds.width - run) / 2
            numberCenter = CGPoint(x: lead + number.width / 2, y: bounds.midY)
            chevron.frame = CGRect(
                x: lead + number.width + Self.sideGap,
                y: (bounds.height - glyph.height) / 2,
                width: glyph.width,
                height: glyph.height
            )
        }
        chip.frame = Self.chipFrame(in: bounds, horizontal: horizontal)
        chip.layer?.cornerRadius = min(
            chipRadius,
            min(chip.frame.width, chip.frame.height) / 2
        )
        // The label centres its text, so centring the label's frame
        // on the digits' place puts the digits there.
        label.frame.origin = CGPoint(
            x: numberCenter.x - label.frame.width / 2,
            y: numberCenter.y - label.frame.height / 2
        )
    }

    /// The chip: the view's own length along the shelf less its
    /// edge slack, a Space item cell's depth across it.
    nonisolated static func chipFrame(
        in bounds: CGRect,
        horizontal: Bool
    ) -> CGRect {
        horizontal
            ? bounds.insetBy(dx: 2, dy: chipInset)
            : bounds.insetBy(dx: chipInset, dy: 2)
    }

    /// The item hover ink over the hover chip, as a Space item
    /// takes them.
    private func applyInk() {
        let hovered = isHovered || isDragHovered
        chip.isHidden = !hovered
        let color = hovered ? hoverInk : ink
        label.textColor = color
        chevron.contentTintColor = color
    }
}
