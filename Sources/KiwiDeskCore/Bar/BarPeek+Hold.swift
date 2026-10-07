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

    /// Whether the pointer is inside the shown peek's hull. Only a
    /// list holds (`BarPeekSource.isList`): a one-window peek is a
    /// label, so it closes as the pointer leaves its item (owner,
    /// #1946).
    var holdsPointer: Bool {
        guard let shown, shown.source.isList,
            let item = shown.frame,
            let peek = panel.panel?.frame, panel.isShown
        else { return false }
        return BarPeekHull.contains(
            pointerOnScreen(),
            item: item,
            peek: peek,
            edge: shown.edge
        )
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

    /// A press in a bar panel (`ShelfPanel`), on `hit`: a click
    /// outside the peek, which closes it — except on a Space Bar
    /// glyph, whose release decides: a list's click toggles the
    /// peek, a one-window glyph's picks.
    func pressed(on hit: NSView?) {
        guard !(hit is SpaceBarGlyphTarget) else { return }
        dismiss()
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
        made.body.onPointerInside = { [weak self] in
            self?.pointerInPeek($0)
        }
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
