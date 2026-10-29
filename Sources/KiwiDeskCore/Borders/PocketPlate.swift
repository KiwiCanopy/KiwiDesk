import AppKit

/// The pocket plate's panel (#2678): a press reaches `onPress` before
/// the view takes it, as on the overflow mark's panel — save the
/// plate's own left press, whose click opens its list.
final class PocketPlatePanel: NSPanel {
    var onPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }

    override func sendEvent(_ event: NSEvent) {
        let hit = contentView?.hitTest(event.locationInWindow)
        if let type = ShelfPanel.pressType(of: event),
            type != .leftMouseDown || !(hit is PocketPlateView)
        {
            onPress(hit, type)
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The pocket plate's drawing (#2678): the brief pocket's look with
/// the count beside the mark, one button to VoiceOver. A click
/// grows the list of the windows inside out of it.
@MainActor
final class PocketPlateView: NSView, BarPeekListAnchor {
    /// A left click on the plate.
    var onClick: @MainActor () -> Void = {}
    /// VoiceOver's press.
    var onPress: @MainActor () -> Void = {}

    let pocket = BriefPocketView(frame: .zero)
    /// A left press landed on the plate; its release decides.
    private var armed = false
    private var tracking: NSTrackingArea?
    /// The pointer on the plate, and a dragged window over it that a
    /// drop would take: either lights it, as a bar item's hover does.
    private var hovered = false
    var dropHovered = false {
        didSet { paintLit() }
    }

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        pocket.autoresizingMask = [.width, .height]
        addSubview(pocket)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    var sparesLeftPress: Bool { true }

    func listOpenChanged() {}

    override func layout() {
        super.layout()
        pocket.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { setHovered(true) }

    override func mouseExited(with event: NSEvent) { setHovered(false) }

    func setHovered(_ on: Bool) {
        guard on != hovered else { return }
        hovered = on
        paintLit()
    }

    /// A window just went in: full ink a moment, then rest.
    var justFilled = false {
        didSet { paintLit() }
    }

    /// Re-applies the look after the pocket re-wore its shelf.
    func paintLit() {
        pocket.setLook(
            hovered || dropHovered
                ? .lit : justFilled ? .active : .rest
        )
    }

    /// The whole plate is one target.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return bounds.contains(local) ? self : nil
    }

    /// Opens on the release inside the plate, as a button acts; a
    /// drag off cancels (#2044).
    override func mouseDown(with event: NSEvent) {
        armed = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { armed = false }
        let point = convert(event.locationInWindow, from: nil)
        guard armed, bounds.contains(point) else { return }
        onClick()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
