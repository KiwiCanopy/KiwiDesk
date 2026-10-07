import AppKit

/// Runs a body after a delay: a timer, or a test's hand.
typealias BarPeekSchedule =
    @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> Void

/// The bars' one hover peek (#1946): a read-only label panel at
/// the hovered item, in place of the system tooltip. Items report
/// what the pointer rests on; this decides when the peek shows,
/// swaps and closes, and asks Core for its content as it shows.
/// The argument is `docs/design-decisions.md` ▸ A bar item's
/// hover peek.
@MainActor
final class BarPeek {
    /// The peek's timing, one home (#1946).
    enum Timing {
        /// The rest before a first peek: long enough that a
        /// pointer crossing a top bar for the menu bar shows
        /// nothing, short enough to read as an answer. Tuned on
        /// the device; the Settings tooltip delay is its own.
        static let dwell: TimeInterval = 0.12
        /// How long after a peek closes the next one shows at
        /// once, so moving along the bar reads as one peek.
        static let coolDown: TimeInterval = 0.4
    }

    /// The content for a source, read when the peek shows; nil
    /// shows nothing.
    var content: @MainActor (BarPeekSource) -> BarPeekContent? = { _ in
        nil
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

    /// An item the peek stands at: what it shows, where it stood.
    struct Anchor {
        weak var view: NSView?
        let source: BarPeekSource
        let edge: AppBarEdge
        var frame: CGRect?
    }

    private(set) var shown: Anchor?
    private(set) var pending: Anchor?
    /// An anchor a click or a move closed: it peeks again only
    /// once the pointer has left it, as a tooltip does.
    private var spent: Anchor?
    private var closedAt: TimeInterval?
    private var generation = 0
    private(set) lazy var panel = BarPeekPanel()
    /// Any menu opening — a glyph's, a right-click's — closes the
    /// peek, which would otherwise stand beside it (#1946).
    private var menuToken: NSObjectProtocol?

    init() {
        menuToken = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    isolated deinit {
        if let menuToken {
            NotificationCenter.default.removeObserver(menuToken)
        }
    }

    /// What `reporter` — an item view — finds under the pointer:
    /// `anchor` and its `source`, or nil where nothing of it peeks.
    /// Every hover reading reports, the relayout's re-read too.
    func pointer(
        in reporter: NSView,
        on anchor: NSView?,
        source: BarPeekSource?,
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
                leave()
            }
            return
        }
        // A reused item view standing for other windows is a new
        // anchor, so the source is compared beside the view.
        guard !Self.same(spent, anchor, source),
            !Self.same(shown, anchor, source),
            !Self.same(pending, anchor, source)
        else { return }
        let next = Anchor(view: anchor, source: source, edge: edge)
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
                let pending = self.pending
            else { return }
            self.present(pending, fades: true)
        }
    }

    /// The pointer left the peeked item: it fades and cools.
    func leave() {
        generation += 1
        pending = nil
        guard shown != nil else { return }
        shown = nil
        closedAt = now()
        panel.hide(animated: true)
    }

    /// A press or a scroll took the item: it closes at once and
    /// stays shut until the pointer leaves it.
    func dismiss() {
        generation += 1
        spent = shown ?? pending
        pending = nil
        closedAt = nil
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

    private func present(_ anchor: Anchor, fades: Bool) {
        generation += 1
        pending = nil
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

    /// Where the peek's top-left corner stands, or would, for
    /// `anchor` — in screen coordinates — so the menu a click opens
    /// lays its rows where the peek's were (owner, device). Read
    /// whether a peek shows or not.
    func topLeft(
        for anchor: NSView,
        source: BarPeekSource,
        edge: AppBarEdge
    ) -> CGPoint? {
        guard let window = anchor.window,
            let frame = Self.screenFrame(of: anchor),
            let content = content(source), !content.groups.isEmpty,
            let shelf = shelf(window)
        else { return nil }
        let visible = Self.visible(of: window)
        let size = BarPeekPanel.fittedSize(
            of: BarPeekBody(),
            content,
            shelf: shelf,
            edge: edge,
            strip: window.frame,
            visible: visible
        )
        let origin = BarPeekPanel.origin(
            size: size,
            edge: edge,
            anchor: frame,
            strip: window.frame,
            visible: visible
        )
        return CGPoint(x: origin.x, y: origin.y + size.height)
    }

    /// The usable area of `window`'s screen.
    private static func visible(of window: NSWindow) -> CGRect {
        window.screen.map(GeometryUtils.visibleFrame(of:)) ?? window.frame
    }

    /// The view's frame on screen; nil off a shown window.
    static func screenFrame(of view: NSView) -> CGRect? {
        guard let window = view.window, window.isVisible,
            !view.isHiddenOrHasHiddenAncestor
        else { return nil }
        return window.convertToScreen(
            view.convert(view.bounds, to: nil)
        )
    }

    private static func same(
        _ held: Anchor?,
        _ view: NSView?,
        _ source: BarPeekSource?
    ) -> Bool {
        guard let held, let view, let source else { return false }
        return held.view === view && held.source == source
    }

    private static func belongs(
        _ view: NSView,
        to reporter: NSView
    ) -> Bool {
        view === reporter || view.isDescendant(of: reporter)
    }
}
