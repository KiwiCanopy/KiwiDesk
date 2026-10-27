import AppKit

/// Metrics for Space Bar badge family sizing (#414): the count
/// dot and state marks derive from ONE factor of the glyph cell
/// so the family shrinks together — one home, since a resize
/// touching one site would silently miss the others. 0.42→0.38,
/// 8→7 (owner 2026-07-21).
enum StateBadgeMetrics {
    static let sizeFactor: CGFloat = 0.38
    static let floor: CGFloat = 7

    /// The badge's diameter/side on a glyph cell of `cell` pts.
    static func side(cell: CGFloat) -> CGFloat {
        max(cell * sizeFactor, floor)
    }
}

/// Resolved tints for sticky, floating and pocket state mark
/// rendering (#429, #2671), carried as data from `KiwiCore` so the
/// Bar subsystem never reaches into the mark namespaces itself.
public struct StateMarkColors: Sendable, Equatable {
    public let sticky: String
    public let floating: String
    public let pocket: String

    public init(sticky: String, floating: String, pocket: String = "") {
        self.sticky = sticky
        self.floating = floating
        self.pocket = pocket
    }
}

/// Space Bar badge view displaying template symbol on circular plate
/// (#414, #429).
final class StateBadgeView: NSView {
    let symbol = NSImageView()
    /// The mark's SF Symbol; a reused badge re-images on a change.
    var symbolName: String {
        didSet {
            guard symbolName != oldValue else { return }
            symbol.image = image()
        }
    }

    /// The pocket badge's ink, which a template symbol takes from
    /// `contentTintColor` instead (#2671).
    var ink: NSColor = .labelColor {
        didSet {
            guard ink != oldValue, symbolName == Self.pocketName
            else { return }
            symbol.image = image()
        }
    }

    init(symbolName: String) {
        self.symbolName = symbolName
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        symbol.image = image()
        symbol.imageScaling = .scaleProportionallyUpOrDown
        symbol.setAccessibilityElement(false)
        addSubview(symbol)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Stands for the pocket badge, drawn by `PocketMark` rather
    /// than a symbol (#2446).
    static let pocketName = "kiwidesk.pocket"

    private func image() -> NSImage? {
        if symbolName == Self.pocketName {
            return PocketMark.badge.image(size: 12, ink: ink)
        }
        return NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
    }

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
