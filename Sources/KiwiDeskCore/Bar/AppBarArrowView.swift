import AppKit

/// A clickable chevron over one end of the indicator bar,
/// shown when items are scrolled away in that direction;
/// boxed in the bar's item color so it stays legible over
/// the item scrolling away beneath it. Hover feedback
/// mirrors the items': the box swaps to the hover color.
@MainActor
final class AppBarArrowView: NSView {
    var onClick: () -> Void = {}
    private let label = NSTextField(labelWithString: "")
    private var style = AppBarStyle()
    private var isHovered = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        isHidden = true
        label.alignment = .center
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppBarArrowView is code-only")
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

    func style(glyph: String, style: AppBarStyle) {
        self.style = style
        label.stringValue = glyph
        label.font = .systemFont(
            ofSize: AppBarOverlay.arrowZone * 0.7,
            weight: .bold
        )
        // The shared %-resolve against the arrow box's own
        // shorter side: 100% is a clean capsule, never an
        // overlapping arc — so no separate pt clamp is needed.
        layer?.cornerRadius = style.resolvedCornerRadius(
            forThickness: min(bounds.width, bounds.height)
        )
        applyColors()
        needsLayout = true
    }

    private func applyColors() {
        let bar = style
        label.textColor = NSColor(
            kiwiHex: isHovered
                ? bar.hoverTextColor : bar.textColor
        )
        layer?.backgroundColor =
            NSColor(
                kiwiHex: isHovered
                    ? bar.hoverColor : bar.boxColor
            ).cgColor
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
