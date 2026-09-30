import AppKit

/// The home-space pill's text (#421): the sentence with its space
/// mark inline, measured to the width the plate grows to.
extension StickyMarkPlate {
    /// Formats attributed text and computes required expanded width.
    func prepare(format: String, mark: SpaceMark) -> CGFloat {
        let content = attributedContent(format: format, mark: mark)
        name.attributedStringValue = content
        let textWidth = ceil(content.size().width) + 1
        let glyphs = Self.size * CGFloat(slotCount)
        let cap =
            Self.maxWidth - Self.namePad - Self.nameGap - glyphs
        let measured = min(textWidth, cap)
        return Self.namePad + measured + Self.nameGap + glyphs
    }

    var nameFont: NSFont {
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
}
