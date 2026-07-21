import AppKit

/// A Space Bar state badge (#414): the group-count badge's
/// circular plate wearing a template symbol instead of a
/// count, so the sticky/floating marks read as the same badge
/// family and hug inside the glyph's corner exactly like the
/// count does.
final class StateBadgeView: NSView {
    let symbol = NSImageView()

    init(symbolName: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        symbol.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
        symbol.imageScaling = .scaleProportionallyUpOrDown
        symbol.setAccessibilityElement(false)
        addSubview(symbol)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        // The plate is what reads as "badge"; the inset mark
        // just names the state (count-badge proportions).
        let inset = bounds.width * 0.2
        symbol.frame = bounds.insetBy(dx: inset, dy: inset)
        layer?.cornerRadius = bounds.width / 2
    }
}
