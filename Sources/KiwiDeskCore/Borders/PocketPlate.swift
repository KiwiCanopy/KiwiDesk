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

/// The pocket's drawing (#2678): a section on a bar's edge, or a
/// handle on an edge no bar shows that the pocket rises out of; one
/// button to VoiceOver. A click grows the list of the windows inside
/// out of it.
@MainActor
final class PocketPlateView: NSView, BarPeekListAnchor {
    /// A left click on the plate.
    var onClick: @MainActor () -> Void = {}
    /// VoiceOver's press.
    var onPress: @MainActor () -> Void = {}

    let pocket = BriefPocketView(frame: .zero)
    /// The handle an edge no bar shows wears (#2678).
    let handle = PocketHandleView(frame: .zero)
    /// The pointer came onto the pocket or left it.
    var onHover: @MainActor (Bool) -> Void = { _ in }
    /// The pointer pushed against the screen edge on a resting
    /// handle, which raises the pocket at once (#2807).
    var onPush: @MainActor () -> Void = {}
    /// The edge a handle stands on; nil for a section on a bar.
    private(set) var handleEdge: AppBarEdge?
    /// Whether the pocket is out of its handle, and at what side.
    private(set) var risen = false
    /// The whole mark stands at rest, with no handle (#2784).
    private(set) var whole = false
    private var risenSide: CGFloat = 0
    /// The shelf's outer margin, kept clear between the edge and the
    /// handle as the bars' handles keep it (#2678).
    private var outer: CGFloat = 0
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
        handle.isHidden = true
        addSubview(handle)
        addSubview(pocket)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    var sparesLeftPress: Bool { true }

    /// The list grown out of it opened or closed, which holds a
    /// risen pocket out (#2678 review 1).
    var onListChanged: @MainActor () -> Void = {}

    func listOpenChanged() { onListChanged() }

    /// Stands as a section, or as a handle on `edge` `outer` in from
    /// it, risen to `side` where `risen`.
    func stand(
        handle edge: AppBarEdge?,
        risen: Bool,
        side: CGFloat,
        outer: CGFloat = 0,
        whole: Bool = false
    ) {
        let rising = risen && !self.risen && edge != nil
        handleEdge = edge
        self.whole = whole
        self.risen = risen
        risenSide = side
        self.outer = outer
        needsLayout = true
        if rising, let edge {
            layoutSubtreeIfNeeded()
            BarMotion.playPocketRise(
                pocket,
                edge: edge,
                side: side,
                peek: handle.risePeek
            )
        }
    }

    override func layout() {
        super.layout()
        guard let edge = handleEdge else {
            handle.isHidden = true
            pocket.isHidden = false
            pocket.frame = bounds
            return
        }
        let room = Self.room(in: bounds, edge: edge, outer: outer)
        // The whole mark on an edge no bar shows: no tab (#2784).
        guard !whole else {
            handle.isHidden = true
            pocket.isHidden = false
            pocket.frame = room
            return
        }
        handle.isHidden = false
        handle.frame = room
        pocket.isHidden = !risen
        pocket.frame = Self.risenFrame(in: room, edge: edge, side: risenSide)
    }

    /// The handle's room inside `bounds`, which reach the screen edge
    /// so a push to it still finds the handle: `outer` in from `edge`.
    static func room(
        in bounds: CGRect,
        edge: AppBarEdge,
        outer: CGFloat
    ) -> CGRect {
        var room = bounds
        switch edge {
        case .bottom: room.size.height -= outer
        case .top:
            room.origin.y += outer
            room.size.height -= outer
        case .left:
            room.origin.x += outer
            room.size.width -= outer
        case .right: room.size.width -= outer
        }
        return room
    }

    /// Where the risen pocket stands inside the handle's room: on its
    /// centre line, its base `lift` past the tab (#2678).
    static func risenFrame(
        in bounds: CGRect,
        edge: AppBarEdge,
        side: CGFloat
    ) -> CGRect {
        let gap = PocketHandleView.tabDepth + lift
        let x: CGFloat
        let y: CGFloat
        switch edge {
        case .bottom:
            x = bounds.midX - side / 2
            y = bounds.maxY - gap - side
        case .top:
            x = bounds.midX - side / 2
            y = bounds.minY + gap
        case .left:
            x = bounds.minX + gap
            y = bounds.midY - side / 2
        case .right:
            x = bounds.maxX - gap - side
            y = bounds.midY - side / 2
        }
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// The risen pocket's clearance past the tab.
    static let lift: CGFloat = 4

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [
                .mouseEnteredAndExited, .mouseMoved, .activeAlways,
                .inVisibleRect,
            ],
            owner: self
        )
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
        reportPush()
    }

    override func mouseMoved(with event: NSEvent) { reportPush() }

    /// Tells `onPush` where a resting handle's pointer stands against
    /// the screen edge, as a bar's band hears a push.
    private func reportPush() {
        guard let edge = handleEdge, !risen, !whole,
            let window, let screen = window.screen,
            ShelfReveal.pushes(
                NSEvent.mouseLocation,
                band: window.frame,
                strip: window.frame,
                edge: edge,
                screen: screen.frame
            )
        else { return }
        onPush()
    }

    override func mouseExited(with event: NSEvent) { setHovered(false) }

    /// Ends a hover whose exit will not come, telling nobody; true
    /// where one was on.
    func dropHover() -> Bool {
        guard hovered else { return false }
        hovered = false
        paintLit()
        return true
    }

    func setHovered(_ on: Bool) {
        guard on != hovered else { return }
        hovered = on
        paintLit()
        onHover(on)
    }

    /// A window just went in or out: the edge a moment, then rest.
    var flashing = false {
        didSet { paintLit() }
    }

    /// Re-applies the look after the pocket re-wore its shelf.
    func paintLit() {
        pocket.setLook(
            hovered || dropHovered
                ? .lit : flashing ? .active : .rest
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
