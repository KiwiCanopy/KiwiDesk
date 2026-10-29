import AppKit

/// The pocket on screen (#2678): one per display — on every display
/// while Several windows holds the pocket. At the slot its shelf's
/// arrangement pins at a bar edge's outer end it is a shelf section,
/// its view handed to the shelf (`sectionMount`), which draws it in
/// the shelf's own motion; on an edge no bar shows it is a handle in
/// a panel of its own. It keeps the drag state while a window may
/// drop onto it.
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
        /// The shelf's outer margin, between the edge and the handle.
        var outer: CGFloat = 0
        /// A window drag runs: the pocket stands above its ghost,
        /// which shares the bars' level (owner, device 2026-10-29).
        var aboveDrag = false
    }

    /// One display's pocket: a handle's panel, or a section's
    /// holder, which its shelf mounts and this fades.
    private struct Shown {
        let panel: PocketPlatePanel?
        let holder: NSView?
        let view: PocketPlateView
    }

    private var shownViews: [DisplayID: Shown] = [:]
    private var sectionViews: [DisplayID: Shown] = [:]
    private(set) var specs: [DisplayID: Spec] = [:]
    /// The displays whose handle the pointer is on.
    var hovered: Set<DisplayID> = []
    /// The displays a put-in or take-out plays on, each with the
    /// play that holds it out; the pocket stands out of its handle
    /// for the play (#2678).
    var playing: [DisplayID: UUID] = [:]
    /// A list opened on or closed off a pocket.
    var onListChanged: @MainActor () -> Void = {}
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
    /// Each screen's handle band along an edge of Auto marks, its
    /// place in their row, AX along the edge (#2678).
    var markBands: [DisplayID: ClosedRange<CGFloat>] = [:]
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
        guard let spec = specs[display] else { return nil }
        return shown(spec)?.view
    }

    /// The display a pocket view stands on.
    func display(of view: PocketPlateView) -> DisplayID? {
        (shownViews.first { $0.value.view === view }
            ?? sectionViews.first { $0.value.view === view })?.key
    }

    /// The view a display's shelf carries at its pocket slot, while
    /// the pocket stands there as a section.
    func sectionMount(on display: DisplayID) -> NSView? {
        guard let spec = specs[display], spec.handle == nil else {
            return nil
        }
        return sectionViews[display]?.holder
    }

    private func shown(_ spec: Spec) -> Shown? {
        spec.handle == nil
            ? sectionViews[spec.display] : shownViews[spec.display]
    }

    #if DEBUG
        /// Test-only: the handle panel standing on `display`.
        func handlePanel(on display: DisplayID) -> NSPanel? {
            shownViews[display]?.panel
        }
    #endif

    /// Every shown pocket's frame, AppKit coordinates.
    var shownFrames: [CGRect] { specs.values.map(\.frame) }

    /// Shows one pocket per spec and hides every other display's.
    func sync(_ next: [Spec]) {
        let wanted = Dictionary(
            next.map { ($0.display, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // A handle's panel goes where its display's pocket is gone
        // or became a section.
        for (display, shown) in shownViews
        where wanted[display]?.handle == nil {
            shown.panel?.orderOut(nil)
            // An ordered-out handle hears no exit (#2678 review 20).
            hovered.remove(display)
        }
        for spec in wanted.values { show(spec) }
        specs = wanted
    }

    private func show(_ spec: Spec) {
        let shown =
            shown(spec)
            ?? made(spec.display, section: spec.handle == nil)
        let old = specs[spec.display]
        if let old, spec.windows.count > old.windows.count {
            flashFilled(shown.view, on: spec.display)
        }
        // A form change reconfigures the other form's view.
        let changed = spec != old || old?.handle != spec.handle
        if changed {
            shown.view.pocket.wear(
                spec.shelf,
                markHex: spec.markHex,
                platePiece: spec.platePiece
            )
            shown.view.handle.wear(
                spec.shelf,
                markHex: spec.markHex,
                edge: spec.handle ?? .bottom,
                kiwisOut: spec.risen
            )
            shown.view.dropHovered = spec.dropHovered
            shown.view.paintLit()
            // An ancestor fades, never the glass (bars.md ▸ glass
            // alpha): the handle's panel, or the section's holder.
            let alpha = spec.faded ? Self.fadedAlpha : 1
            shown.panel?.alphaValue = alpha
            shown.holder?.alphaValue = alpha
            shown.view.setAccessibilityLabel(spec.name)
            if let panel = shown.panel, panel.frame != spec.frame {
                panel.setFrame(spec.frame, display: false)
            }
            if shown.panel != nil {
                shown.view.frame = CGRect(
                    origin: .zero,
                    size: spec.frame.size
                )
            }
        }
        orderIn(shown, spec: spec, changed: changed)
        // Sized and ordered in first: a pocket that rises out of a
        // handle made this pass has no layer to rise on before.
        if changed {
            shown.view.stand(
                handle: spec.handle,
                risen: spec.risen,
                side: spec.risenSide,
                outer: spec.outer
            )
        }
    }

    private func orderIn(_ shown: Shown, spec: Spec, changed: Bool) {
        guard let panel = shown.panel else { return }
        let level = spec.aboveDrag ? BarPanel.aboveLevel : BarPanel.level
        if panel.level != level { panel.level = level }
        #if DEBUG
            guard ordersPanel else { return }
        #endif
        if !panel.isVisible || changed {
            panel.orderFrontRegardless()
        }
    }

    /// Drops every display's pocket outside `live`, a display that
    /// left (#2678 review 20).
    func retire(except live: Set<DisplayID>) {
        for (display, shown) in shownViews where !live.contains(display) {
            shown.panel?.orderOut(nil)
            shownViews[display] = nil
        }
        for display in sectionViews.keys where !live.contains(display) {
            sectionViews[display]?.holder?.removeFromSuperview()
            sectionViews[display] = nil
        }
        hovered.formIntersection(live)
        specs = specs.filter { live.contains($0.key) }
    }

    /// How long a put-in holds the pocket at full ink.
    static let filledHold: TimeInterval = 1.2
    /// Each display's light, so one display's flash never strands
    /// another's lit (#2678 review 8).
    private var filledGeneration: [DisplayID: Int] = [:]

    /// Holds `view` at full ink after a window went in, then lets it
    /// rest — a timer, its own, since the light is no motion.
    private func flashFilled(_ view: PocketPlateView, on display: DisplayID) {
        let mine = (filledGeneration[display] ?? 0) + 1
        filledGeneration[display] = mine
        view.justFilled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.filledHold) {
            [weak self, weak view] in
            guard let self, self.filledGeneration[display] == mine
            else { return }
            view?.justFilled = false
        }
    }

    /// The shelf a pocket wears in `window`, its panel — the peek
    /// growing out of it wears it too.
    func shelf(drawnIn window: NSWindow) -> KiwiShelf? {
        // A section's panel is its shelf's, which ShelfManager owns.
        shownViews.first { $0.value.panel === window }
            .flatMap { specs[$0.key]?.shelf }
    }

    private func made(_ display: DisplayID, section: Bool) -> Shown {
        let view = PocketPlateView()
        wire(view, on: display)
        guard !section else {
            let holder = AppBarOverlay.FlippedView()
            view.autoresizingMask = [.width, .height]
            holder.addSubview(view)
            let shown = Shown(panel: nil, holder: holder, view: view)
            sectionViews[display] = shown
            return shown
        }
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
        panel.contentView = view
        panel.onPress = { [weak self] hit, type in
            self?.onPanelPress(hit, type)
        }
        let shown = Shown(panel: panel, holder: nil, view: view)
        shownViews[display] = shown
        return shown
    }

    private func wire(_ view: PocketPlateView, on display: DisplayID) {
        view.onClick = { [weak self, weak view] in
            guard let view else { return }
            self?.onClick(view)
        }
        view.onPress = view.onClick
        view.onHover = { [weak self] on in
            self?.onHover(display, on)
        }
        view.onListChanged = { [weak self] in self?.onListChanged() }
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
        for shown in shownViews.values { shown.panel?.orderOut(nil) }
    }
}
