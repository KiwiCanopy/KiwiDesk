import AppKit

/// Visual representation of a space mark (#421).
public enum SpaceMark: Equatable {
    case symbol(String)
    case text(String)
}

/// Visual plate displaying sticky indicator glyph and space pill
/// (#414, #421). A clipping container: the `.hudWindow` backing or,
/// under Liquid Glass, tinted glass (#1621, `+Glass`), with the
/// glyphs in `content` above either.
@MainActor
final class StickyMarkPlate: NSView {
    /// Collapsed badge square dimension.
    static let size: CGFloat = 20
    /// Padding and gap metrics.
    static let namePad: CGFloat = 8
    static let nameGap: CGFloat = 4
    /// Maximum expanded pill width.
    static let maxWidth: CGFloat = 360
    /// Corner radii for collapsed square and expanded capsule.
    static let collapsedRadius: CGFloat = size / 4
    static let expandedRadius: CGFloat = size / 2

    /// The `.hudWindow` backing; hidden while the mark is glass.
    let hud = NSVisualEffectView()
    /// The glyphs, hosted by the plate or by the glass (#1621).
    let content = NSView()
    /// The glass, hosted once asked for; nil below macOS 26.
    var glass: NSView?
    let tint = GlassBackdrop()
    /// Whether the mark draws as glass (`setGlass`).
    var isGlass = false
    /// The stored colour, kept for the glass tint.
    var markHex = ""

    let symbol = NSImageView()
    let name = NSTextField(labelWithString: "")
    /// Background disc behind mark glyph (#429).
    let roundel = NSView()
    /// Diameter of background roundel.
    static let roundelSize: CGFloat = 15

    /// Resolved tint color (#429).
    var markColor: NSColor = .labelColor

    init() {
        super.init(
            frame: CGRect(
                x: 0,
                y: 0,
                width: Self.size,
                height: Self.size
            )
        )
        wantsLayer = true
        layer?.cornerRadius = Self.collapsedRadius
        layer?.masksToBounds = true
        hud.material = .hudWindow
        hud.state = .active
        for view in [hud, content, tint] as [NSView] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
        }

        symbol.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize: Self.size * 0.55,
                weight: .semibold
            )
        symbol.contentTintColor = .labelColor
        symbol.imageScaling = .scaleProportionallyDown

        name.font = .systemFont(ofSize: 11, weight: .semibold)
        name.textColor = .labelColor
        name.drawsBackground = false
        name.isBordered = false
        name.isEditable = false
        name.lineBreakMode = .byTruncatingTail
        name.usesSingleLineMode = true
        name.alphaValue = 0

        roundel.wantsLayer = true
        roundel.layer?.cornerRadius = Self.roundelSize / 2
        roundel.isHidden = true

        addSubview(hud)
        addSubview(content)
        content.addSubview(name)
        content.addSubview(roundel)
        content.addSubview(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Sets mark tint hex color and updates roundel appearance (#429).
    func setMarkColor(_ hex: String) {
        markHex = hex
        guard !isGlass else {
            applyGlass()
            return
        }
        if hex.isEmpty {
            markColor = .labelColor
            roundel.isHidden = true
            symbol.contentTintColor = .labelColor
        } else {
            let fill = NSColor(kiwiHex: hex)
            markColor = fill
            roundel.isHidden = false
            roundel.layer?.backgroundColor = fill.cgColor
            symbol.contentTintColor = fill.contrastingGlyph
        }
        name.textColor = markColor
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        symbol.frame = CGRect(
            x: w - Self.size,
            y: 0,
            width: Self.size,
            height: Self.size
        )
        let inset = (Self.size - Self.roundelSize) / 2
        roundel.frame = CGRect(
            x: w - Self.size + inset,
            y: inset,
            width: Self.roundelSize,
            height: Self.roundelSize
        )
        let textHeight = ceil(name.intrinsicContentSize.height)
        let right = w - Self.size - Self.nameGap
        name.frame = CGRect(
            x: Self.namePad,
            y: (Self.size - textHeight) / 2,
            width: max(0, right - Self.namePad),
            height: textHeight
        )
    }

    /// Formats attributed text and computes required expanded width.
    func prepare(format: String, mark: SpaceMark) -> CGFloat {
        let content = attributedContent(format: format, mark: mark)
        name.attributedStringValue = content
        let textWidth = ceil(content.size().width) + 1
        let cap =
            Self.maxWidth - Self.namePad - Self.nameGap - Self.size
        let measured = min(textWidth, cap)
        return Self.namePad + measured + Self.nameGap + Self.size
    }

    private var nameFont: NSFont {
        name.font ?? .systemFont(ofSize: 11, weight: .semibold)
    }

    private func attributedContent(
        format: String,
        mark: SpaceMark
    ) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: markColor,
        ]
        let parts = format.components(separatedBy: "%1$@")
        let out = NSMutableAttributedString(
            string: parts.first ?? "",
            attributes: attrs
        )
        switch mark {
        case .text(let value):
            out.append(
                NSAttributedString(string: value, attributes: attrs)
            )
        case .symbol(let symbolName):
            out.append(symbolRun(symbolName, attrs: attrs))
        }
        if parts.count > 1 {
            out.append(
                NSAttributedString(
                    string: parts[1],
                    attributes: attrs
                )
            )
        }
        return out
    }

    /// Generates inline image attachment for symbol mark.
    private func symbolRun(
        _ symbolName: String,
        attrs: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(
            pointSize: nameFont.pointSize,
            weight: .semibold
        )
        .applying(
            NSImage.SymbolConfiguration(paletteColors: [markColor])
        )
        guard
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )?.withSymbolConfiguration(config)
        else {
            return NSAttributedString(
                string: symbolName,
                attributes: attrs
            )
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let mid = (nameFont.capHeight - image.size.height) / 2
        attachment.bounds = CGRect(
            x: 0,
            y: mid,
            width: image.size.width,
            height: image.size.height
        )
        return NSAttributedString(attachment: attachment)
    }

    /// Toggles visibility of space name label and morphs capsule shape.
    func setNameShown(
        _ shown: Bool,
        animated: Bool,
        duration: TimeInterval
    ) {
        let radius =
            shown ? Self.expandedRadius : Self.collapsedRadius
        if animated {
            name.animator().alphaValue = shown ? 1 : 0
            animateCornerRadius(to: radius, over: duration)
        } else {
            name.alphaValue = shown ? 1 : 0
            layer?.cornerRadius = radius
        }
    }

    /// Animates layer corner radius.
    func animateCornerRadius(
        to radius: CGFloat,
        over duration: TimeInterval
    ) {
        guard let layer else { return }
        let anim = CABasicAnimation(keyPath: "cornerRadius")
        anim.fromValue = layer.cornerRadius
        anim.toValue = radius
        anim.duration = duration
        layer.add(anim, forKey: "cornerRadius")
        layer.cornerRadius = radius
    }
}
