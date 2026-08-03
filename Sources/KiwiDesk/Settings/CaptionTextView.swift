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

    /// Every property that makes this view a caption rather
    /// than an editor, in ONE place. `LinkedCaption.makeNSView`
    /// and the test fixture both build through here: a fixture
    /// that hand-rebuilt this configuration went green while
    /// `isSelectable` was flipped back to `true`, which is the
    /// single thing the class exists to avoid.
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

    /// Not `private` only because the AX overrides that read
    /// it live one file over (`CaptionTextViewAX.swift`) — a
    /// stored property cannot go in an extension.
    lazy var linkElement: LinkAccessibilityElement = {
        let element = LinkAccessibilityElement()
        element.onPress = { [weak self] in self?.activateLink() }
        element.setAccessibilityRole(.link)
        element.setAccessibilityParent(self)
        return element
    }()

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
            value: linkColor(pointing: overLink),
            range: linkRange
        )
    }

    /// The colour DECISION, lifted out for the same reason
    /// `wantsPointingHand(at:)` is: the lift only ever happens
    /// under a pointer, every route to which needs a window, so
    /// a test asserting the painted storage can only ever see
    /// the at-rest value and cannot fail differently when the
    /// caption greys.
    func linkColor(pointing: Bool) -> NSColor {
        pointing && isLive
            ? .labelColor
            : .secondaryLabelColor
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

    /// The cursor DECISION, lifted out of the event path so it
    /// can be asserted without a machine. Every route into
    /// `apply` differs only in where the point comes from, and
    /// all of them need a window — so with this inline, the
    /// pointing hand, which is the reason this class exists, was
    /// reachable by no test at all (guard-prover, 2026-08-03).
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

    /// The caption is a tab stop only while it has somewhere to
    /// go — the affordance for a channel that does not exist is
    /// removed outright, not offered dead (gui.md).
    override var acceptsFirstResponder: Bool {
        isLive && linkRange.length > 0
    }

    /// `super`, not a bare `acceptsFirstResponder`: the
    /// default also requires the view to be un-hidden and in a
    /// window, and dropping those leaves an invisible tab stop
    /// inside a hidden ancestor.
    override var canBecomeKeyView: Bool { super.canBecomeKeyView }

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
    ///
    /// Seeded with the FIRST rect, never `.zero`. `NSRect.zero`
    /// is a real rect at the origin rather than an empty one, so
    /// `reduce(.zero)` unions in the point (0,0) and the mask
    /// stretched from the view's left edge across the whole
    /// leading prose — the opposite of what the sentence above
    /// promises, shipped and green because the test computed its
    /// expectation with this same expression (guard-prover,
    /// 2026-08-03).
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
