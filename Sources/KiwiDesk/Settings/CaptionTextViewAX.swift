import AppKit

/// Accessibility surface for `CaptionTextView` exposing link activation.
extension CaptionTextView {
    override func accessibilityRole() -> NSAccessibility.Role? {
        .group
    }

    override func accessibilityLabel() -> String? {
        textStorage?.string
    }

    override func accessibilityChildren() -> [Any]? {
        guard !linkLabel.isEmpty else { return nil }
        let rects = linkRects()
        guard let first = rects.first else { return nil }
        let element = linkElement
        element.setAccessibilityLabel(linkLabel)
        element.setAccessibilityFrameInParentSpace(
            rects.dropFirst().reduce(first) { $0.union($1) }
        )
        return [element]
    }
}

/// Accessibility element representing a clickable link within a caption.
final class LinkAccessibilityElement: NSAccessibilityElement {
    var onPress: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }

    override func isAccessibilityElement() -> Bool { true }
}
