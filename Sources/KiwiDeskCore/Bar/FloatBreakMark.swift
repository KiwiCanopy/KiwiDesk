import AppKit

/// The App Bar's floating mark: the shared symbol, inert to the
/// pointer and silent to VoiceOver, which hears "floating" on each
/// item.
final class FloatBreakMark: NSImageView {
    private var drawn: (side: CGFloat, weight: NSFont.Weight)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        imageScaling = .scaleProportionallyUpOrDown
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FloatBreakMark is code-only")
    }

    /// The symbol's configuration at `side` points and `weight`
    /// (the bar text's, `KiwiShelf.symbolWeight`), so its strokes
    /// never fall below the titles' on a light plate.
    static func configuration(
        side: CGFloat,
        weight: NSFont.Weight
    ) -> NSImage.SymbolConfiguration {
        NSImage.SymbolConfiguration(pointSize: side, weight: weight)
            .applying(.preferringMonochrome())
    }

    /// Draws the symbol for `side` and `weight`.
    func draw(side: CGFloat, weight: NSFont.Weight) {
        guard drawn?.side != side || drawn?.weight != weight else { return }
        drawn = (side, weight)
        image = NSImage(
            systemSymbolName: FloatingStyle.symbolName,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(
            Self.configuration(side: side, weight: weight)
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
