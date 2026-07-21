import AppKit

/// Shared size for the Space Bar's badge family (#414): the
/// group-count dot and the sticky/floating state marks all
/// derive from ONE factor of the glyph cell (floored for
/// legibility on thin bars), so the three read as one family
/// and shrink together. One home for the constant so a future
/// resize can't touch one site and forget the other (§5
/// mirror hygiene). Trimmed 0.42→0.38 / 8→7 (owner 2026-07-21,
/// ui-designer consult).
enum StateBadgeMetrics {
    static let sizeFactor: CGFloat = 0.38
    static let floor: CGFloat = 7

    /// The badge's diameter/side on a glyph cell of `cell` pts.
    static func side(cell: CGFloat) -> CGFloat {
        max(cell * sizeFactor, floor)
    }
}

/// The two state-mark tints resolved for one bar render (#429):
/// the raw hex a sticky / floating badge glyph draws in (empty =
/// "Automatic", resolved to the adaptive `.labelColor` by
/// `NSColor.mark`). Carried as data from `KiwiCore` — which owns
/// both `StickyStyle` and `FloatingStyle` — so the Bar subsystem
/// renders the marks without reaching into the sticky/floating
/// namespaces itself.
public struct StateMarkColors: Sendable, Equatable {
    public let sticky: String
    public let floating: String

    public init(sticky: String, floating: String) {
        self.sticky = sticky
        self.floating = floating
    }
}

/// A Space Bar state badge (#414): the count badge's circular
/// plate wearing a template symbol instead of a count. Since #429
/// the sticky/floating marks leave the count badge's colored fill:
/// the glyph carries the chosen state color and the plate goes
/// neutral (owner "colored glyph, neutral plate"). It still hugs
/// inside the glyph's corner exactly like the count does.
final class StateBadgeView: NSView {
    /// The neutral plate behind a state-mark glyph (#429): a faint
    /// appearance-adaptive scrim that seats the colored glyph in
    /// its corner without competing with it — the mark's color is
    /// the signal, not the plate's. (The count badge keeps its own
    /// solid `groupBadgeColor` fill; this is the state marks only.)
    static let neutralPlate =
        NSColor.labelColor.withAlphaComponent(0.12)

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
