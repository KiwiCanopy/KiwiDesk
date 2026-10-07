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
    /// The content for a source, read when the peek shows; nil
    /// shows nothing.
    var content: @MainActor (BarPeekSource) -> BarPeekContent? = { _ in
        nil
    }
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

    /// An item the peek stands at: what it shows, where it stood.
    struct Anchor {
        weak var view: NSView?
        let source: BarPeekSource
        /// The Space Bar chip's Space; nil on the App Bar.
        let space: SpaceID?
        let edge: AppBarEdge
        var frame: CGRect?
    }

    private(set) var shown: Anchor?
    private(set) var pending: Anchor?
    /// A click on a list showed it at once (#1946): it holds until
    /// a click outside, a pick, or the pointer leaving the hull.
    private(set) var pinned = false
    /// The pointer left the item for the hull: the peek holds while
    /// a poll finds it there.
    var holding = false
    /// An anchor a click or a move closed: it peeks again only
    /// once the pointer has left it, as a tooltip does.
    private var spent: Anchor?
    private var closedAt: TimeInterval?
    var generation = 0
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
        if Self.same(shown, anchor, source) {
            holding = false
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
        pending = next
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

    /// A click on a multi-window glyph or `+n` (#1946): its peek
    /// shows at once, with no dwell, and holds — pinned — until a
    /// click outside, a pick, or the pointer leaving the hull.
    func pin(
        _ anchor: NSView,
        source: BarPeekSource,
        space: SpaceID?,
        edge: AppBarEdge
    ) {
        spent = nil
        if !Self.same(shown, anchor, source) {
            present(
                Anchor(view: anchor, source: source, space: space, edge: edge),
                fades: false
            )
        }
        pinned = shown != nil
    }

    /// The pointer left the peeked item for good: it fades and cools.
    func leave() {
        generation += 1
        pending = nil
        holding = false
        pinned = false
        guard shown != nil else { return }
        shown = nil
        closedAt = now()
        panel.hide(animated: true)
    }

    /// A press, a pick or a scroll took the item: it closes at once
    /// and stays shut until the pointer leaves it — a second
    /// dismiss, the press's menu opening, keeps that mark.
    func dismiss() {
        generation += 1
        spent = shown ?? pending ?? spent
        pending = nil
        closedAt = nil
        holding = false
        pinned = false
        guard shown != nil else { return }
        shown = nil
        panel.hide(animated: false)
    }

    /// The shelf drawn in `window` left — stood down, turned off,
    /// its display gone: a peek standing on it closes with it.
    func shelfLeft(_ window: NSWindow?) {
        guard let window,
            (shown ?? pending)?.view?.window === window
        else { return }
        dismiss()
    }

    /// A render or a switch that moved the peeked item, or took it
    /// off screen, closes the peek — the relayout's tail.
    func syncToAnchor() {
        guard let anchor = shown else { return }
        guard let view = anchor.view,
            let frame = Self.screenFrame(of: view),
            frame == anchor.frame
        else {
            dismiss()
            return
        }
    }

    private var coolingDown: Bool {
        guard let closedAt else { return false }
        return now() - closedAt < Timing.coolDown
    }

    func present(_ anchor: Anchor, fades: Bool) {
        generation += 1
        pending = nil
        holding = false
        pinned = false
        guard let view = anchor.view, let window = view.window,
            let frame = Self.screenFrame(of: view),
            let content = content(anchor.source),
            !content.groups.isEmpty,
            let shelf = shelf(window)
        else {
            if shown != nil {
                shown = nil
                panel.hide(animated: false)
            }
            return
        }
        var placed = anchor
        placed.frame = frame
        shown = placed
        panel.show(
            content,
            shelf: shelf,
            edge: anchor.edge,
            anchor: frame,
            strip: window.frame,
            visible: Self.visible(of: window),
            fades: fades
        )
    }
}
