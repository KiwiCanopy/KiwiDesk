import AppKit

/// Runs a body after a delay: a timer, or a test's hand.
typealias BarPeekSchedule =
    @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void

/// The bars' one hover peek (#1946): a panel at the hovered item
/// listing its windows, in place of the system tooltip, each row
/// that window's button. Items report what the pointer rests on;
/// this decides when the peek shows, swaps, holds and closes, and
/// asks Core for its content as it shows. The argument is
/// `docs/design-decisions.md` ▸ A bar item's hover peek.
@MainActor
final class BarPeek {
    /// The content for a source on a chip's Space (nil on the App
    /// Bar), read when the peek shows; nil shows nothing.
    var content: @MainActor (BarPeekSource, SpaceID?) -> BarPeekContent? =
        { _, _ in nil }
    /// A row picked: its window, on the anchor's Space where it has
    /// one — Core's one bar-row pick, the glyph menu's too.
    var pick: @MainActor (WindowID, SpaceID?) -> Void = { _, _ in }
    /// "N more" pressed: the full menu of the anchor's windows,
    /// opened at the anchor.
    var openMenu: @MainActor (BarPeekSource, SpaceID?, NSView) -> Void = {
        _,
        _,
        _ in
    }
    /// The stored shelf the bar panel `window` draws, which the
    /// peek wears — `ShelfManager`'s; its render gates it.
    var shelf: @MainActor (NSWindow) -> KiwiShelf? = { _ in nil }
    /// Runs `body` after a delay; both `makeTestCore` twins pin it
    /// inert, so no fixture's hover opens a panel.
    var schedule: BarPeekSchedule = { delay, body in
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            body()
        }
    }
    /// Seconds on a monotonic clock, for the cool-down.
    var now: @MainActor () -> TimeInterval = {
        ProcessInfo.processInfo.systemUptime
    }
    /// The pointer on screen, for the hull; both `makeTestCore`
    /// twins pin it off every screen.
    var pointerOnScreen: @MainActor () -> CGPoint = {
        NSEvent.mouseLocation
    }
    /// The usable area the peek is fitted into for `window`'s
    /// screen; a test pins it, since a runner's screen may not
    /// hold the host window at all.
    var visibleArea: @MainActor (NSWindow) -> CGRect = {
        BarPeek.visible(of: $0)
    }

    private(set) var phase = Phase.idle
    /// An anchor a click or a move closed: it peeks again only
    /// once the pointer has left it, as a tooltip does.
    private var spent: Anchor?
    private var closedAt: TimeInterval?
    /// Stamps every timer it schedules; a phase change outdates them.
    private var generation = 0
    /// The pointer is inside the peek's body, whose own tracking
    /// reports it, so a held peek polls the gap fast and re-reads
    /// slowly inside, which heals an exit the body never got.
    private var pointerInPeek = false
    private(set) lazy var panel = wiredPanel()
    /// Any menu opening — a right-click's, "N more"'s — closes the
    /// peek, which would otherwise stand beside it, and none opens
    /// while one tracks: the relayout re-reads the pointer the
    /// click left on the item (#1946).
    private var menuTokens: [NSObjectProtocol] = []
    private var menusTracking = 0
    private let menuCentre: NotificationCenter

    /// `menus` posts the menus' tracking: the app's, or a test's
    /// own, so a test's menu never reaches another suite's peek.
    init(menus centre: NotificationCenter = .default) {
        menuCentre = centre
        menuTokens = [
            centre.addObserver(
                forName: NSMenu.didBeginTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuBegan() }
            },
            centre.addObserver(
                forName: NSMenu.didEndTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.menuEnded() }
            },
        ]
    }

    isolated deinit {
        menuTokens.forEach(menuCentre.removeObserver)
    }

    private func menuBegan() {
        menusTracking += 1
        dismiss()
    }

    private func menuEnded() {
        menusTracking = max(menusTracking - 1, 0)
    }

    /// What `reporter` — an item view — finds under the pointer:
    /// `anchor` and its `source`, or nil where nothing of it peeks.
    /// Every hover reading reports, the relayout's re-read too.
    func pointer(
        in reporter: NSView,
        on anchor: NSView?,
        source: BarPeekSource?,
        space: SpaceID? = nil,
        edge: AppBarEdge
    ) {
        if let gone = spent?.view, Self.belongs(gone, to: reporter),
            !Self.same(spent, anchor, source)
        {
            spent = nil
        }
        guard let anchor, let source else {
            let current = shown?.view ?? pending?.view
            if let current, Self.belongs(current, to: reporter) {
                released()
            }
            return
        }
        // Back on its own item, a held peek stops polling.
        if case .showing(let held, _) = phase,
            Self.same(held, anchor, source)
        {
            phase = .showing(held, holding: false)
            return
        }
        // A reused item view standing for other windows is a new
        // anchor, so the source is compared beside the view; a
        // neighbour inside the hull does not swap in.
        guard menusTracking == 0,
            !Self.same(spent, anchor, source),
            !Self.same(pending, anchor, source),
            !holdsPointer
        else { return }
        let next = Anchor(
            view: anchor,
            source: source,
            space: space,
            edge: edge
        )
        if shown != nil || coolingDown {
            // A swap, or a peek moving on along the bar: no fade.
            present(next, fades: false)
            return
        }
        phase = .dwelling(next)
        generation += 1
        let ticket = generation
        schedule(Timing.dwell) { [weak self] in
            guard let self, ticket == self.generation,
                self.menusTracking == 0,
                let pending = self.pending
            else { return }
            self.present(pending, fades: true)
        }
    }

    /// A click on a list (#1946, `BarPeekSource.isList`) toggles
    /// its peek: one already showing — the hover's, or a click's —
    /// closes; otherwise it shows at once, with no dwell, and holds
    /// as any list's does, until a click outside, a pick, or the
    /// pointer leaving the hull.
    func toggle(
        _ anchor: NSView,
        source: BarPeekSource,
        space: SpaceID?,
        edge: AppBarEdge
    ) {
        if Self.same(shown, anchor, source) {
            dismiss()
            return
        }
        show(anchor, source: source, space: space, edge: edge)
    }

    /// Shows the peek at `anchor` at once, with no dwell — or, where
    /// it shows already, re-reads it in place — held as any list's
    /// is: a glyph's click after its focus moved, so the check
    /// stands on the window it landed (#2063).
    func show(
        _ anchor: NSView,
        source: BarPeekSource,
        space: SpaceID?,
        edge: AppBarEdge
    ) {
        spent = nil
        present(
            Anchor(view: anchor, source: source, space: space, edge: edge),
            fades: false
        )
    }

    /// The pointer left the peeked item for good: it fades and cools.
    func leave() {
        let was = shown
        close()
        guard was != nil else { return }
        closedAt = now()
        panel.hide(animated: true)
    }

    /// A press, a pick or a scroll took the item: it closes at once
    /// and stays shut until the pointer leaves it — a second
    /// dismiss, the press's menu opening, keeps that mark.
    func dismiss() {
        let was = shown
        spent = shown ?? pending ?? spent
        close()
        closedAt = nil
        guard was != nil else { return }
        panel.hide(animated: false)
    }

    private func close() {
        generation += 1
        phase = .idle
        pointerInPeek = false
    }

    /// The item reported the pointer gone: inside the hull a list's
    /// peek holds, re-reading the pointer across the gap no view
    /// tracks; outside it, or for a label, it closes.
    func released() {
        guard case .showing(let anchor, let held) = phase, holdsPointer
        else {
            leave()
            return
        }
        guard !held else { return }
        phase = .showing(anchor, holding: true)
        generation += 1
        poll(generation)
    }

    /// The peek's body reports the pointer entering or leaving it:
    /// inside, the hold's poll slows to `Timing.insideRecheck`;
    /// leaving it, the hull is read again — a held peek polls the
    /// gap, or closes outside it.
    func bodyReported(inside: Bool) {
        pointerInPeek = inside
        guard holding, !inside else { return }
        guard holdsPointer else {
            leave()
            return
        }
        generation += 1
        poll(generation)
    }

    /// Re-reads the hull while the peek holds: across the gap at
    /// `holdPoll`, inside the body at `insideRecheck`, since an
    /// exit can be lost (a view moved under a resting pointer gets
    /// none, #1665; a press dragged out with the button held).
    private func poll(_ ticket: Int) {
        let delay = pointerInPeek ? Timing.insideRecheck : Timing.holdPoll
        schedule(delay) { [weak self] in
            guard let self, self.holding, ticket == self.generation
            else { return }
            guard self.holdsPointer else {
                self.leave()
                return
            }
            self.poll(ticket)
        }
    }

    private var coolingDown: Bool {
        guard let closedAt else { return false }
        return now() - closedAt < Timing.coolDown
    }

    private func present(_ anchor: Anchor, fades: Bool) {
        let was = shown
        close()
        guard let view = anchor.view, let window = view.window,
            let frame = Self.screenFrame(of: view),
            let content = content(anchor.source, anchor.space),
            !content.groups.isEmpty,
            let shelf = shelf(window)
        else {
            if was != nil { panel.hide(animated: false) }
            return
        }
        var placed = anchor
        placed.frame = frame
        phase = .showing(placed, holding: false)
        panel.show(
            content,
            shelf: shelf,
            edge: anchor.edge,
            anchor: frame,
            strip: window.frame,
            visible: visibleArea(window),
            fades: fades
        )
    }
}
