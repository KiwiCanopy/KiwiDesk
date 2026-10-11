import AppKit

/// The pill's visual content: frosted blur plate with symbol and label.
@MainActor
final class SizeLimitPillPlate: NSVisualEffectView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.masksToBounds = true

        // Sized explicitly, matching `StickyMarkPlate`: with no
        // configuration the symbol renders at the default point
        // size and scales down into a 12 pt box, which draws a
        // dense glyph like `nosign` too thin to read (#1260).
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 11,
            weight: .semibold
        )
        icon.contentTintColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyDown
        addSubview(icon)

        label.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    func setText(_ text: String) {
        label.stringValue = text
    }

    /// The leading glyph, chosen by the refusal's own case
    /// (`ResizeRefusal.pillSymbol`).
    func setSymbol(_ name: String) {
        icon.image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: nil
        )
    }

    override var fittingSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 36, height: 26)
    }

    override func layout() {
        super.layout()
        icon.frame = NSRect(
            x: 8,
            y: (bounds.height - 12) / 2,
            width: 12,
            height: 12
        )
        label.frame = NSRect(
            x: 24,
            y: (bounds.height - 15) / 2,
            width: bounds.width - 30,
            height: 15
        )
    }
}
