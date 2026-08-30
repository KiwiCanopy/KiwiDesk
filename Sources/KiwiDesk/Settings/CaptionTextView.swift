import AppKit

/// Non-selectable text view with custom link click, hover cursor, keyboard
/// focus, and accessibility support.
final class CaptionTextView: NSTextView {
    var onLink: (() -> Void)?
    var linkLabel: String = ""
    /// Mirrors SwiftUI's `isEnabled`. A greyed caption must not claim hover
    /// or focus.
    var isLive = true {
        didSet { if isLive != oldValue { refreshCursor() } }
    }

    /// The one place configuring non-selectable caption text view properties
    /// (LinkedCaptionHitTests).
    static func configured() -> CaptionTextView {
        let view = CaptionTextView()
        view.isEditable = false
        view.isSelectable = false
        view.drawsBackground = false
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = false
        view.isHorizontallyResizable = false
        view.focusRingType = .exterior
        return view
    }

    lazy var linkElement: LinkAccessibilityElement = {
        let element = LinkAccessibilityElement()
        element.onPress = { [weak self] in self?.activateLink() }
        element.setAccessibilityRole(.link)
        element.setAccessibilityParent(self)
        return element
    }()

    /// Base prose ink color (#828).
    var restingInk: NSColor = .secondaryLabelColor {
        didSet { paintLink() }
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
        // AppKit CACHES the focus-ring mask, so a caption that
        // is first responder while the text or the wrap changes
        // would keep ringing the link's old rects.
        noteFocusRingMaskChanged()
    }

    /// Secondary at rest, primary under the pointer.
    private func paintLink() {
        guard let storage = textStorage, storage.length > 0
        else { return }
        storage.addAttribute(
            .foregroundColor,
            value: restingInk,
            range: NSRange(location: 0, length: storage.length)
        )
        guard linkRange.upperBound <= storage.length else {
            return
        }
        storage.addAttribute(
            .foregroundColor,
            value: linkColor(pointing: overLink),
            range: linkRange
        )
    }

    func linkColor(pointing: Bool) -> NSColor {
        pointing && isLive
            ? .labelColor
            : .secondaryLabelColor
    }

    // MARK: - Pointer

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
        apply(wantsPointingHand(at: location(of: event)))
    }

    override func mouseExited(with event: NSEvent) {
        apply(false)
    }

    override func mouseDown(with event: NSEvent) {
        guard wantsPointingHand(at: location(of: event)) else {
            super.mouseDown(with: event)
            return
        }
        activateLink()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { apply(false) }
    }

    override func layout() {
        super.layout()
        refreshCursor()
        noteFocusRingMaskChanged()
    }

    private func refreshCursor() {
        guard let window, window.isKeyWindow else { return }
        let point = convert(
            window.mouseLocationOutsideOfEventStream,
            from: nil
        )
        apply(bounds.contains(point) && wantsPointingHand(at: point))
    }

    func wantsPointingHand(at point: NSPoint) -> Bool {
        isLive && isOverLink(point)
    }

    private func apply(_ pointing: Bool) {
        guard pointing != overLink else { return }
        overLink = pointing
        (pointing ? NSCursor.pointingHand : NSCursor.arrow).set()
        paintLink()
    }

    // MARK: - Keyboard & accessibility

    func activateLink() {
        guard isLive else { return }
        onLink?()
    }

    override var acceptsFirstResponder: Bool {
        isLive && linkRange.length > 0
    }

    override var canBecomeKeyView: Bool { super.canBecomeKeyView }

    override func keyDown(with event: NSEvent) {
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

    /// Focus ring bounding the link glyph rects, seeded with first rect.
    override var focusRingMaskBounds: NSRect {
        let rects = linkRects()
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    override func drawFocusRingMask() {
        for rect in linkRects() { rect.fill() }
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
