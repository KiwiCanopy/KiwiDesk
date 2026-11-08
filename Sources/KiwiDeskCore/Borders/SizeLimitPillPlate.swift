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

    /// The label's font, shared with `textHeight` so a measure and
    /// a draw cannot disagree.
    nonisolated static var font: NSFont {
        NSFont.systemFont(ofSize: 11.5, weight: .medium)
    }

    /// The most lines a pill wraps to; past it the last one ends
    /// in "…".
    nonisolated static let maxLines = 3

    /// The one-line pill's height; a wrapped pill adds its lines.
    nonisolated static let lineHeight: CGFloat = 26

    /// The height of `text` wrapped at `width`, capped at
    /// `maxLines` lines. Pure, so a test can read it headless.
    nonisolated static func textHeight(
        _ text: String,
        width: CGFloat
    ) -> CGFloat {
        let font = Self.font
        let line = ceil(font.ascender - font.descender + font.leading)
        let drawn = NSAttributedString(
            string: text,
            attributes: [.font: font]
        ).boundingRect(
            with: NSSize(
                width: max(width, 1),
                height: .greatestFiniteMagnitude
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return min(ceil(drawn.height), line * CGFloat(maxLines))
    }

    /// The pill's height at `width`: one line keeps `lineHeight`,
    /// each wrapped line adds its own.
    func height(forWidth width: CGFloat) -> CGFloat {
        let text = Self.textHeight(
            label.stringValue,
            width: width - textInset - 6
        )
        return max(Self.lineHeight, text + 11)
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
        let textHeight = max(15, bounds.height - 11)
        label.frame = NSRect(
            x: textInset,
            y: (bounds.height - textHeight) / 2,
            width: bounds.width - textInset - 6,
            height: textHeight
        )
    }
}
