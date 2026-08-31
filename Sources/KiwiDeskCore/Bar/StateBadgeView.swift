import AppKit

/// Metrics for Space Bar badge family sizing (#414).
enum StateBadgeMetrics {
    static let sizeFactor: CGFloat = 0.38
    static let floor: CGFloat = 7

    /// The badge's diameter/side on a glyph cell of `cell` pts.
    static func side(cell: CGFloat) -> CGFloat {
        max(cell * sizeFactor, floor)
    }
}

/// Resolved tints for sticky and floating state mark rendering (#429).
public struct StateMarkColors: Sendable, Equatable {
    public let sticky: String
    public let floating: String

    public init(sticky: String, floating: String) {
        self.sticky = sticky
        self.floating = floating
    }
}

/// Space Bar badge view displaying template symbol on circular plate
/// (#414, #429).
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
