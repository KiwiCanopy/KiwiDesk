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
    /// VoiceOver's press, which opens the native menu (#2936).
    var onPress: @MainActor () -> Void = {}

    let pocket = BriefPocketView(frame: .zero)
    /// The handle an edge no bar shows wears (#2678).
    let handle = PocketHandleView(frame: .zero)
    /// The pointer came onto the pocket or left it.
    var onHover: @MainActor (Bool) -> Void = { _ in }
    /// The pointer moved over the panel, Cocoa screen space: the
    /// revealer's monitors miss KiwiDesk's own panels while another
    /// app is active, so the handle's approach hears it here too
    /// (#3368).
    var onMove: @MainActor (CGPoint) -> Void = { _ in }
    /// The edge a handle stands on; nil for a section on a bar.
    private(set) var handleEdge: AppBarEdge?
    /// Whether the pocket is out of its handle, and at what side.
    private(set) var risen = false
    /// The whole mark stands at rest, with no handle (#2784).
    private(set) var whole = false
    private var risenSide: CGFloat = 0
    /// The tab's depth on the shelf it stands on (#3451), handed to
    /// `stand` from the spec whose shelf the handle wears, so it
    /// equals `handle.tabDepth`.
    private var tabDepth: CGFloat = 0
    /// The approach's countdown the pocket rises on (#3368).
    private(set) var rise: ShelfHandleSpec.Fill?
    /// The sink running into the handle, nil where none does: the
    /// one owner of a sink (#3383), whose landing ends only the sink
    /// it was handed (`endSink(_:)`).
    private(set) var sink: UUID?
    /// A rise taken back is sinking into the handle.
    var sinking: Bool { sink != nil }
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

    /// How a handle stood before a stand, read from the spec it last
    /// wore — the one source of "was it up" (#3383).
    struct Before: Equatable {
        var risen = false
        var rise: ShelfHandleSpec.Fill?
        var isUp: Bool { risen || rise != nil }
    }

    /// Stands as a section, or as a handle on `edge` `outer` in from
    /// it, risen to `side` where `risen`, else rising on `rise`, its
    /// approach's countdown (#3368), at the fast pace while `fast`. A
    /// rise taken back, or a risen pocket going to rest, sinks from
    /// where it is drawn (#3383); `before` is how it stood. Returns
    /// how long that sink runs, 0 where none does: the panel keeps
    /// the risen room until `endSink(_:)` with `sink`. Every motion
    /// travels to the kiwis' look-out while it `holds` something or
    /// not, the spec's verdict (#3446).
    @discardableResult
    func stand(
        handle edge: AppBarEdge?,
        risen: Bool,
        side: CGFloat,
        outer: CGFloat = 0,
        whole: Bool = false,
        rise: ShelfHandleSpec.Fill? = nil,
        fast: Bool = false,
        holds: Bool,
        tabDepth: CGFloat,
        before: Before = Before()
    ) -> TimeInterval {
        let rising = risen && !before.risen && edge != nil
        let was = before.rise
        handleEdge = edge
        self.whole = whole
        self.risen = risen
        self.rise = edge == nil || risen ? nil : rise
        risenSide = side
        self.tabDepth = tabDepth
        self.outer = outer
        // A rise, a risen stand or the whole mark ends any sink.
        if self.rise != nil || risen || whole {
            if sink != nil, whole {
                pocket.layer?.removeAnimation(forKey: BarMotion.pocketRiseKey)
            }
            sink = nil
        }
        needsLayout = true
        guard let edge else { return 0 }
        layoutSubtreeIfNeeded()
        let travel = BarMotion.pocketRiseTravel(
            holds: holds,
            tabDepth: tabDepth
        )
        if rising {
            BarMotion.playPocketRise(
                pocket,
                edge: edge,
                side: side,
                travel: travel,
                up: was != nil
            )
        } else if let next = self.rise, next != was {
            BarMotion.playPocketScrub(
                pocket,
                edge: edge,
                side: side,
                travel: travel,
                rise: next,
                pace: PocketRiseTimeline.pace(onTab: fast)
            )
        } else if before.isUp, self.rise == nil, !risen, !whole {
            let span = BarMotion.playPocketSink(
                pocket,
                edge: edge,
                side: side,
                travel: travel,
                risen: before.risen
            )
            sink = span > 0 ? UUID() : nil
            needsLayout = true
            return span
        }
        return 0
    }

    /// The sink `token` names landed: the pocket hides in its handle
    /// again. A later sink or a rise meanwhile owns the pocket.
    func endSink(_ token: UUID) {
        guard sink == token else { return }
        sink = nil
        pocket.layer?.removeAnimation(forKey: BarMotion.pocketRiseKey)
        needsLayout = true
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
        pocket.isHidden = !(risen || rise != nil || sinking)
        handle.hidesKiwis = rise != nil || sinking
        pocket.frame = Self.risenFrame(
            in: room,
            edge: edge,
            side: risenSide,
            tabDepth: tabDepth
        )
    }

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
        reportMove(event)
    }

    override func mouseMoved(with event: NSEvent) { reportMove(event) }

    private func reportMove(_ event: NSEvent) {
        guard let window else { return }
        onMove(window.convertPoint(toScreen: event.locationInWindow))
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
