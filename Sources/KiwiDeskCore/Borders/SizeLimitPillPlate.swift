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

        label.font = Self.font
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = Self.maxLines
        label.usesSingleLineMode = false
        label.cell?.truncatesLastVisibleLine = true
        addSubview(label)
    }

    required init?(coder: NSCoder) { nil }

    func setText(_ text: String) {
        label.stringValue = text
    }

    /// The leading glyph, chosen by the refusal's own case
    /// (`ResizeRefusal.pillSymbol`); nil draws the text alone.
    func setSymbol(_ name: String?) {
        icon.image = name.flatMap {
            NSImage(systemSymbolName: $0, accessibilityDescription: nil)
        }
        icon.isHidden = name == nil
        needsLayout = true
    }

    private var textInset: CGFloat { icon.isHidden ? 12 : 24 }

    /// The label's font, shared by the one-line width measure.
    nonisolated static var font: NSFont {
        NSFont.systemFont(ofSize: 11.5, weight: .medium)
    }

    /// The most lines a pill wraps to; past it the last one ends
    /// in "…".
    nonisolated static let maxLines = 3

    /// The one-line pill's height; a wrapped pill adds its lines.
    nonisolated static let lineHeight: CGFloat = 26

    /// The plate's vertical padding around the label, top and
    /// bottom together.
    private static let verticalPad: CGFloat = 11

    /// The label's trailing inset inside the plate.
    private static let trailingPad: CGFloat = 6

    /// One wrapped line's height, as the label's cell draws it.
    var textLineHeight: CGFloat { drawnHeight("X", width: 1000) }

    /// The label's drawn height for `text` at the label width a
    /// pill of `width` gives it, measured by the label's own cell
    /// so the measure and the wrap cannot disagree; capped at
    /// `maxLines` lines.
    func textHeight(forWidth width: CGFloat) -> CGFloat {
        let labelWidth = width - textInset - Self.trailingPad
        let drawn = drawnHeight(label.stringValue, width: labelWidth)
        return min(drawn, textLineHeight * CGFloat(Self.maxLines))
    }

    private func drawnHeight(_ text: String, width: CGFloat) -> CGFloat {
        guard let cell = label.cell?.copy() as? NSCell else { return 15 }
        cell.stringValue = text
        let size = cell.cellSize(
            forBounds: NSRect(
                x: 0,
                y: 0,
                width: max(width, 1),
                height: .greatestFiniteMagnitude
            )
        )
        return ceil(size.height)
    }

    /// The pill's height at `width`: one line keeps `lineHeight`,
    /// each wrapped line adds its own.
    func height(forWidth width: CGFloat) -> CGFloat {
        max(Self.lineHeight, textHeight(forWidth: width) + Self.verticalPad)
    }

    /// The width the text asks for on one line, before the
    /// window's cap (`SizeLimitOverlay.pillWidth`).
    override var fittingSize: NSSize {
        let one = NSAttributedString(
            string: label.stringValue,
            attributes: [.font: Self.font]
        ).size().width
        return NSSize(
            width: ceil(one) + textInset + 12,
            height: Self.lineHeight
        )
    }

    override func layout() {
        super.layout()
        icon.frame = NSRect(
            x: 8,
            y: (bounds.height - 12) / 2,
            width: 12,
            height: 12
        )
        let textHeight = max(15, bounds.height - Self.verticalPad)
        label.frame = NSRect(
            x: textInset,
            y: (bounds.height - textHeight) / 2,
            width: bounds.width - textInset - Self.trailingPad,
            height: textHeight
        )
    }
}
