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

/// The pocket plate on screen (#2678): one panel, on the screen of
/// the active Space, at the pocket's edge and position, while
/// Several windows holds two windows without a key of their own.
@MainActor
final class PocketPlateOverlay {
    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    /// What the plate draws: its screen, its windows, its frame (AppKit), the
    /// gated shelf, the mark's colour, the count — the mark's
    /// square trailing it where `markTrailing` — and VoiceOver's
    /// name.
    struct Spec: Equatable {
        let display: DisplayID
        /// The windows it lists.
        let windows: [WindowID]
        let frame: CGRect
        let shelf: KiwiShelf
        let markHex: String
        /// Empty from two down: no count is drawn.
        let count: String
        let markTrailing: Bool
        /// The empty pocket, shown only as a drag's target.
        let faded: Bool
        /// A dragged window over it that a drop would take.
        let dropHovered: Bool
        let name: String
    }

    let view = PocketPlateView()
    /// A press on the panel, ahead of the view.
    var onPanelPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }
    private(set) var panel: PocketPlatePanel?
    private(set) var shown: Spec?
    /// The screens the last bar pass stood down on, which the plate
    /// stands down on too.
    var standingDown: Set<DisplayID> = []
    /// The window a drag moves, while one does: the plate is its
    /// drop target (#2678).
    var dragging: WindowID?
    /// Whether that window is over the plate and a drop takes it.
    var dropHovered = false

    /// The empty pocket's opacity while a drag shows it.
    static let fadedAlpha: CGFloat = 0.55

    #if DEBUG
        /// Whether the plate orders its panel in; off in both
        /// `makeTestCore` twins (#1894's shape, as the shelf's).
        var ordersPanel = true
    #endif

    /// Shows the plate as `spec` says, or hides it for nil.
    func sync(_ spec: Spec?) {
        guard let spec else {
            panel?.orderOut(nil)
            shown = nil
            return
        }
        let panel = self.panel ?? made()
        if spec != shown {
            view.pocket.wear(
                spec.shelf,
                markHex: spec.markHex,
                count: spec.count.isEmpty ? nil : spec.count,
                markTrailing: spec.markTrailing
            )
            view.pocket.setDropHovered(spec.dropHovered)
            // The panel fades, never the glass (bars.md ▸ glass alpha).
            panel.alphaValue = spec.faded ? Self.fadedAlpha : 1
            view.setAccessibilityLabel(spec.name)
            if panel.frame != spec.frame {
                panel.setFrame(spec.frame, display: false)
            }
            view.frame = CGRect(origin: .zero, size: spec.frame.size)
        }
        shown = spec
        #if DEBUG
            guard ordersPanel else { return }
        #endif
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    /// The shelf the plate wears in `window`, its panel — the peek
    /// growing out of it wears it too.
    func shelf(drawnIn window: NSWindow) -> KiwiShelf? {
        guard let panel, panel === window else { return nil }
        return shown?.shelf
    }

    private func made() -> PocketPlatePanel {
        let panel = BarPanel.configure(
            PocketPlatePanel(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        panel.level = BarPanel.level
        // The pocket is beside the Spaces, so its plate is on every
        // Desktop.
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .canJoinAllSpaces, .stationary,
        ]
        panel.contentView = view
        panel.onPress = { [weak self] hit, type in
            self?.onPanelPress(hit, type)
        }
        self.panel = panel
        return panel
    }
}
