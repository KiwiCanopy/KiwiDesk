import AppKit

/// A non-selectable text view that owns its own click, cursor,
/// keyboard activation and accessibility. All four are here
/// because the selectable version gave the whole caption an
/// I-beam with no way to override it, and dropping selection
/// takes AppKit's link machinery with it.
final class CaptionTextView: NSTextView {
    var onLink: (() -> Void)?
    var linkLabel: String = ""
    /// Mirrors SwiftUI's `isEnabled`. A greyed caption must not
    /// navigate, or the dim says "switch that on and I act"
    /// while acting anyway (gui.md, grey-don't-hide).
    var isLive = true {
        didSet { if isLive != oldValue { refreshCursor() } }
    }

    private var hover: NSTrackingArea?
    private var linkRange = NSRange(location: 0, length: 0)
    private var overLink = false

    // MARK: - Content

    func setSentence(
        _ sentence: NSAttributedString,
        linkRange: NSRange
    ) {
        self.linkRange = linkRange
        textStorage?.setAttributedString(sentence)
        paintLink()
        // The stored text just moved under a pointer that has
        // not itself moved, so the memo in `apply` would keep
        // whatever it last decided. Re-ask.
        refreshCursor()
        setAccessibilityChildren(nil)
    }

    /// Secondary at rest, primary under the pointer — the same
    /// lift `LinkHover` gives the tree's other inline links, so
    /// the app keeps ONE link idiom. Colour does not change
    /// metrics, so this needs no relayout.
    private func paintLink() {
        guard let storage = textStorage, storage.length > 0
        else { return }
        storage.addAttribute(
            .foregroundColor,
            value: NSColor.secondaryLabelColor,
            range: NSRange(location: 0, length: storage.length)
        )
        guard linkRange.upperBound <= storage.length else {
            return
        }
        storage.addAttribute(
            .foregroundColor,
            value: overLink && isLive
                ? NSColor.labelColor
                : NSColor.secondaryLabelColor,
            range: linkRange
        )
    }

    // MARK: - Pointer

    /// `.mouseMoved` rather than `.cursorUpdate`: the cursor has
    /// to change as the pointer crosses from prose INTO the link
    /// within one view, and a cursor-update area only fires on
    /// entering and leaving the area itself.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hover { removeTrackingArea(hover) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseMoved,
                .mouseEnteredAndExited,
                .activeInKeyWindow,
                .inVisibleRect,
            ],
            owner: self
        )
        addTrackingArea(area)
        hover = area
    }

    override func mouseMoved(with event: NSEvent) {
        apply(isOverLink(location(of: event)))
    }

    override func mouseExited(with event: NSEvent) {
        apply(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard isLive, isOverLink(location(of: event)) else {
            super.mouseDown(with: event)
            return
        }
        activateLink()
    }

    /// A view removed under the pointer never delivers its own
    /// exit, so the arrow is restored here too — the imbalance
    /// `NSCursor.set()` exists to survive (gui.md, SwiftUI
    /// traps). `set()`, never push/pop.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { apply(false) }
    }

    /// Layout can move the link's glyphs out from under a
    /// stationary pointer with no mouse event to notice it.
    override func layout() {
        super.layout()
        refreshCursor()
    }

    private func refreshCursor() {
        guard let window, window.isKeyWindow else { return }
        let point = convert(
            window.mouseLocationOutsideOfEventStream,
            from: nil
        )
        apply(bounds.contains(point) && isOverLink(point))
    }

    private func apply(_ overLink: Bool) {
        let live = overLink && isLive
        guard live != self.overLink else { return }
        self.overLink = live
        (live ? NSCursor.pointingHand : NSCursor.arrow).set()
        paintLink()
    }

    // MARK: - Keyboard & accessibility

    func activateLink() {
        guard isLive else { return }
        onLink?()
    }

    /// The caption is a tab stop only while it has somewhere to
    /// go — the affordance for a channel that does not exist is
    /// removed outright, not offered dead (gui.md).
    override var acceptsFirstResponder: Bool {
        isLive && linkRange.length > 0
    }

    override var canBecomeKeyView: Bool { acceptsFirstResponder }

    override func keyDown(with event: NSEvent) {
        // Return, Enter, Space — what a `.plain` Button answered
        // to before this view replaced one.
        if [36, 76, 49].contains(Int(event.keyCode)) {
            activateLink()
            return
        }
        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return super.resignFirstResponder()
    }

    /// The ring hugs the LINK, not the whole caption: the
    /// sentence is not the target, one phrase inside it is.
    override var focusRingMaskBounds: NSRect {
        linkRects().reduce(NSRect.zero) { $0.union($1) }
    }

    override func drawFocusRingMask() {
        for rect in linkRects() { rect.fill() }
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .group
    }

    override func accessibilityLabel() -> String? {
        textStorage?.string
    }

    /// One child, the link, so VoiceOver reads the sentence and
    /// then offers exactly the thing that can be activated —
    /// which a bare `AXTextArea` offered not at all.
    override func accessibilityChildren() -> [Any]? {
        guard let rect = linkRects().first, !linkLabel.isEmpty
        else { return nil }
        let element = LinkAccessibilityElement()
        element.onPress = { [weak self] in self?.activateLink() }
        element.setAccessibilityRole(.link)
        element.setAccessibilityLabel(linkLabel)
        element.setAccessibilityParent(self)
        element.setAccessibilityFrameInParentSpace(rect)
        return [element]
    }

    // MARK: - Geometry

    private func location(of event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    func isOverLink(_ point: NSPoint) -> Bool {
        linkRects().contains { $0.contains(point) }
    }

    func linkRects() -> [NSRect] {
        guard
            let storage = textStorage,
            let manager = layoutManager,
            let container = textContainer
        else { return [] }
        let origin = textContainerOrigin
        var rects: [NSRect] = []
        storage.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: storage.length)
        ) { value, range, _ in
            guard value != nil else { return }
            let glyphs = manager.glyphRange(
                forCharacterRange: range,
                actualCharacterRange: nil
            )
            manager.enumerateEnclosingRects(
                forGlyphRange: glyphs,
                withinSelectedGlyphRange: NSRange(
                    location: NSNotFound,
                    length: 0
                ),
                in: container
            ) { rect, _ in
                rects.append(
                    rect.offsetBy(dx: origin.x, dy: origin.y)
                )
            }
        }
        return rects
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
