import AppKit

/// Clickable chevron view for scrolling App Bar and Space Bar ends (#385).
@MainActor
final class BarArrowView: NSView {
    /// Depth of clickable scroll-arrow zones at bar ends.
    nonisolated static let zone: CGFloat = 24

    var onClick: () -> Void = {}
    private let label = NSTextField(labelWithString: "")
    private var colors = BarArrowColors.placeholder
    private var isHovered = false
    private var isDragHovered = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        isHidden = true
        label.alignment = .center
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BarArrowView is code-only")
    }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .activeAlways,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyColors()
    }

    /// Synthetic hover state for foreign AX drag gestures (#385).
    func setDragHover(_ hovered: Bool) {
        guard isDragHovered != hovered else { return }
        isDragHovered = hovered
        applyColors()
    }

    func configure(glyph: String, colors: BarArrowColors) {
        self.colors = colors
        label.stringValue = glyph
        label.font = .systemFont(
            ofSize: Self.zone * 0.7,
            weight: .bold
        )
        layer?.cornerRadius =
            max(0, min(colors.cornerRoundness, 100)) / 100
            * (min(bounds.width, bounds.height) / 2)
        applyColors()
        needsLayout = true
    }

    private func applyColors() {
        let lit = isHovered || isDragHovered
        label.textColor = lit ? colors.hoverText : colors.text
        layer?.backgroundColor =
            (lit ? colors.hover : colors.box).cgColor
    }

    override func layout() {
        super.layout()
        label.sizeToFit()
        label.frame.origin = CGPoint(
            x: (bounds.width - label.frame.width) / 2,
            y: (bounds.height - label.frame.height) / 2
        )
    }
}

/// Resolved colors for BarArrowView rendering across bar types (#385).
struct BarArrowColors {
    let text: NSColor
    let hoverText: NSColor
    let box: NSColor
    let hover: NSColor
    let cornerRoundness: CGFloat

    static let placeholder = BarArrowColors(
        text: .labelColor,
        hoverText: .labelColor,
        box: .clear,
        hover: .clear,
        cornerRoundness: 0
    )
}
