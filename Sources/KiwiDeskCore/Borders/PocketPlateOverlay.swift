import AppKit

/// The pocket on screen (#2678): one panel per display — on every
/// display while Several windows holds the pocket — at the slot
/// its shelf's arrangement pins at a bar edge's outer end, and
/// the drag state while a window may drop onto it.
@MainActor
final class PocketPlateOverlay {
    /// What one display's pocket draws: its screen, its windows,
    /// its frame (AppKit), the gated shelf, the mark's colour, the
    /// count badge, the edge it stands on and VoiceOver's name.
    struct Spec: Equatable {
        let display: DisplayID
        /// The windows it lists.
        let windows: [WindowID]
        let frame: CGRect
        let shelf: KiwiShelf
        let markHex: String
        /// Empty from two down: no badge is drawn.
        let count: String
        /// The badge takes the corner facing into the screen.
        let badgeLeading: Bool
        /// Its own piece of plate: Hug and Boxed; under Full the
        /// shelf's plate runs beneath it.
        let platePiece: Bool
        /// The empty pocket, drawn faded.
        let faded: Bool
        /// A dragged window over it that a drop would take.
        let dropHovered: Bool
        let name: String
        /// The edge its handle stands on, nil for a bar's section.
        var handle: AppBarEdge? = nil
        /// Out of its handle (hover, drag), at this side.
        var risen = false
        var risenSide: CGFloat = 0
    }

    private struct Shown {
        let panel: PocketPlatePanel
        let view: PocketPlateView
    }

    private var shownViews: [DisplayID: Shown] = [:]
    private(set) var specs: [DisplayID: Spec] = [:]
    /// The displays whose handle the pointer is on.
    var hovered: Set<DisplayID> = []
    /// The displays a put-in or take-out plays on, each with the
    /// play that holds it out; the pocket stands out of its handle
    /// for the play (#2678).
    var playing: [DisplayID: UUID] = [:]
    /// The pointer came onto a display's pocket or left it.
    var onHover: @MainActor (DisplayID, Bool) -> Void = { _, _ in }
    /// A click on one display's pocket, and a press on its panel.
    var onClick: @MainActor (PocketPlateView) -> Void = { _ in }
    var onPanelPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }
    /// The screens the last bar pass stood down on.
    var standingDown: Set<DisplayID> = []
    /// Each screen's pocket slot from the last bar pass, AX.
    var slots: [DisplayID: CGRect] = [:]
    /// The window a drag moves, while one does (#2678).
    var dragging: WindowID?
    /// Whether that window is over a pocket and a drop takes it.
    var dropHovered = false
    /// The dropped window, its frame before the drag and where it
    /// was let go, which the brief pocket flies from.
    var dropStart: (window: WindowID, frame: CGRect, released: CGRect)?
    /// The gesture read as a resize, which shows no drop target.
    var resizing: WindowID?

    /// The empty pocket's opacity.
    static let fadedAlpha: CGFloat = 0.55

    #if DEBUG
        /// Whether the pockets order their panels in; off in both
        /// `makeTestCore` twins (#1894's shape, as the shelf's).
        var ordersPanel = true
    #endif

    /// The display's pocket view, while one is shown there.
    func view(on display: DisplayID) -> PocketPlateView? {
        specs[display] == nil ? nil : shownViews[display]?.view
    }

    /// The display a pocket view stands on.
    func display(of view: PocketPlateView) -> DisplayID? {
        shownViews.first { $0.value.view === view }?.key
    }

    /// Every shown pocket's frame, AppKit coordinates.
    var shownFrames: [CGRect] { specs.values.map(\.frame) }

    /// Shows one pocket per spec and hides every other display's.
    func sync(_ next: [Spec]) {
        let wanted = Dictionary(
            next.map { ($0.display, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (display, shown) in shownViews where wanted[display] == nil {
            shown.panel.orderOut(nil)
        }
        for spec in wanted.values { show(spec) }
        specs = wanted
    }

    private func show(_ spec: Spec) {
        let shown = shownViews[spec.display] ?? made(spec.display)
        let old = specs[spec.display]
        if let old, spec.windows.count > old.windows.count {
            flashFilled(shown.view)
        }
        if spec != old {
            shown.view.pocket.wear(
                spec.shelf,
                markHex: spec.markHex,
                badge: spec.count.isEmpty ? nil : spec.count,
                badgeLeading: spec.badgeLeading,
                platePiece: spec.platePiece
            )
            shown.view.handle.wear(
                spec.shelf,
                markHex: spec.markHex,
                edge: spec.handle ?? .bottom,
                empty: spec.windows.isEmpty,
                kiwisOut: spec.risen
            )
            shown.view.stand(
                handle: spec.handle,
                risen: spec.risen,
                side: spec.risenSide
            )
            shown.view.dropHovered = spec.dropHovered
            shown.view.paintLit()
            // The panel fades, never the glass (bars.md ▸ glass alpha).
            shown.panel.alphaValue = spec.faded ? Self.fadedAlpha : 1
            shown.view.setAccessibilityLabel(spec.name)
            if shown.panel.frame != spec.frame {
                shown.panel.setFrame(spec.frame, display: false)
            }
            shown.view.frame = CGRect(origin: .zero, size: spec.frame.size)
        }
        #if DEBUG
            guard ordersPanel else { return }
        #endif
        if !shown.panel.isVisible || spec != old {
            shown.panel.orderFrontRegardless()
        }
    }

    /// How long a put-in holds the pocket at full ink.
    static let filledHold: TimeInterval = 1.2
    private var filledGeneration = 0

    /// Holds `view` at full ink after a window went in, then lets it
    /// rest — a timer, its own, since the light is no motion.
    private func flashFilled(_ view: PocketPlateView) {
        filledGeneration += 1
        let mine = filledGeneration
        view.justFilled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.filledHold) {
            [weak self, weak view] in
            guard let self, self.filledGeneration == mine else { return }
            view?.justFilled = false
        }
    }

    /// The shelf a pocket wears in `window`, its panel — the peek
    /// growing out of it wears it too.
    func shelf(drawnIn window: NSWindow) -> KiwiShelf? {
        shownViews.first { $0.value.panel === window }
            .flatMap { specs[$0.key]?.shelf }
    }

    private func made(_ display: DisplayID) -> Shown {
        let panel = BarPanel.configure(
            PocketPlatePanel(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        // The bars' peer; ordered in after its shelf's panel, which
        // may run beneath it under Full.
        panel.level = BarPanel.level
        // The pocket is beside the Spaces, so it is on every Desktop.
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .canJoinAllSpaces, .stationary,
        ]
        let view = PocketPlateView()
        panel.contentView = view
        panel.onPress = { [weak self] hit, type in
            self?.onPanelPress(hit, type)
        }
        view.onClick = { [weak self, weak view] in
            guard let view else { return }
            self?.onClick(view)
        }
        view.onPress = view.onClick
        view.onHover = { [weak self] on in
            self?.onHover(display, on)
        }
        let shown = Shown(panel: panel, view: view)
        shownViews[display] = shown
        return shown
    }

    #if DEBUG
        /// The display's panel, for a test that reads its window.
        func panelForTesting(on display: DisplayID) -> NSWindow? {
            shownViews[display]?.panel
        }
    #endif

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        for shown in shownViews.values { shown.panel.orderOut(nil) }
    }
}
