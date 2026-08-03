import AppKit

/// The accessibility surface of a caption's link, split from
/// `CaptionTextView` on §2.3: the pointer/cursor machine and the
/// AX surface are two jobs, and the file crossed §2.1's target
/// carrying both.
///
/// It exists at all because a non-selectable `NSTextView` is an
/// `AXTextArea` with nothing activatable in it — AppKit routes
/// link activation through the selection machinery this view
/// gives up to avoid an I-beam over a caption.
extension CaptionTextView {
    override func accessibilityRole() -> NSAccessibility.Role? {
        .group
    }

    override func accessibilityLabel() -> String? {
        textStorage?.string
    }

    /// One child, the link, so VoiceOver reads the sentence and
    /// then offers exactly the thing that can be activated —
    /// which a bare `AXTextArea` offered not at all.
    /// The element is built ONCE and updated, never minted per
    /// call: `setAccessibilityParent` makes no strong reference,
    /// so a fresh element per query is owned only by the array
    /// it is returned in — VoiceOver queries children
    /// repeatedly and holds what it gets, so the link's AX
    /// identity churned on every traversal.
    override func accessibilityChildren() -> [Any]? {
        guard !linkLabel.isEmpty else { return nil }
        let rects = linkRects()
        guard let first = rects.first else { return nil }
        let element = linkElement
        element.setAccessibilityLabel(linkLabel)
        // The union, not the first line: a wrapped link's focus
        // ring covers every line and its AX highlight must not
        // cover only one of them.
        element.setAccessibilityFrameInParentSpace(
            rects.dropFirst().reduce(first) { $0.union($1) }
        )
        return [element]
    }
}

/// The activation target VoiceOver sees. `NSAccessibilityElement`
/// carries no action of its own, so the press is a stored
/// closure back to the view.
final class LinkAccessibilityElement: NSAccessibilityElement {
    var onPress: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }

    override func isAccessibilityElement() -> Bool { true }
}
