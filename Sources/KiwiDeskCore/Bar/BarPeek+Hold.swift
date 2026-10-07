import AppKit

/// The peek's grace and its rows (#1946, owner ruling): it holds
/// while the pointer is inside `BarPeekHull`, and a row picks its
/// window through Core's one bar-row pick.
extension BarPeek {
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
        /// How often a held peek re-reads the pointer while it
        /// crosses the gap no view tracks (`BarPeekHull`).
        static let holdPoll: TimeInterval = 0.05
    }

    /// Whether the pointer is inside the shown peek's hull.
    var holdsPointer: Bool {
        guard let shown, let item = shown.frame,
            let peek = panel.panel?.frame, panel.isShown
        else { return false }
        return BarPeekHull.contains(
            pointerOnScreen(),
            item: item,
            peek: peek,
            edge: shown.edge
        )
    }

    /// The item reported the pointer gone: inside the hull the peek
    /// holds, re-reading the pointer across the gap no view tracks;
    /// outside it, it closes.
    func released() {
        guard shown != nil, holdsPointer else {
            leave()
            return
        }
        guard !holding else { return }
        holding = true
        generation += 1
        poll(generation)
    }

    private func poll(_ ticket: Int) {
        schedule(Timing.holdPoll) { [weak self] in
            guard let self, self.holding, ticket == self.generation
            else { return }
            guard self.holdsPointer else {
                self.leave()
                return
            }
            self.poll(ticket)
        }
    }

    /// A row's window picked: the peek closes and Core focuses it.
    /// A row of a peek already closing, its fade still on screen,
    /// picks nothing.
    func picked(_ window: WindowID) {
        guard let shown else { return }
        dismiss()
        pick(window, shown.space)
    }

    /// "N more": the full menu at the anchor, which closes the peek
    /// as any menu does.
    func openedMore() {
        guard let shown, let view = shown.view else { return }
        openMenu(shown.source, shown.space, view)
    }

    /// The panel, its body's buttons wired to this peek.
    func wiredPanel() -> BarPeekPanel {
        let made = BarPeekPanel()
        made.body.onPick = { [weak self] in self?.picked($0) }
        made.body.onMore = { [weak self] in self?.openedMore() }
        return made
    }

    /// The usable area of `window`'s screen.
    static func visible(of window: NSWindow) -> CGRect {
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

    static func same(
        _ held: Anchor?,
        _ view: NSView?,
        _ source: BarPeekSource?
    ) -> Bool {
        guard let held, let view, let source else { return false }
        return held.view === view && held.source == source
    }

    static func belongs(
        _ view: NSView,
        to reporter: NSView
    ) -> Bool {
        view === reporter || view.isDescendant(of: reporter)
    }
}
