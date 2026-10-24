import AppKit

/// A bar item whose list a click holds open (#2571): it draws its
/// open state while the list shows, re-reading it as the list opens
/// and closes.
@MainActor
protocol BarPeekListAnchor: NSView {
    func listOpenChanged()
}

/// The lists a click holds open (#2563, #2571 ▸ Ruling): the one
/// peek, grown out of its anchor, held until a close and keyed.
extension BarPeek {
    /// A list held open by a click (#2563) closes: a Desktop switch
    /// or KiwiVision turning on or off makes it stale.
    func dismissHeld() {
        guard shown?.source.opensOnClick == true else { return }
        dismiss()
    }

    /// Whether `view` anchors the click-held list showing — what its
    /// open-state highlight reads (#2571).
    func holdsOpen(_ view: NSView) -> Bool {
        guard let shown, shown.view === view, panel.drawn != nil else {
            return false
        }
        return shown.source.opensOnClick
    }

    /// A click on a click-held list's item (#2571): opens its list,
    /// or closes the one it holds open — save the second press of
    /// the double-click that opened it, which keeps it (#2063).
    func clicked(
        _ anchor: NSView,
        source: BarPeekSource,
        space: SpaceID?,
        edge: AppBarEdge,
        clickCount: Int
    ) {
        if let shown, Self.same(shown, anchor, source),
            panel.drawn != nil
        {
            if panel.pressCloses(clickCount) { dismiss() } else { reread() }
            return
        }
        show(anchor, source: source, space: space, edge: edge)
    }

    /// Tells a click-held list's anchor its open state changed.
    func noteOpenChanged(_ anchor: Anchor?) {
        guard let anchor, anchor.source.opensOnClick else { return }
        (anchor.view as? any BarPeekListAnchor)?.listOpenChanged()
    }

    /// The panel shown for `anchor` framed `frame`: a hover peek, or
    /// a list grown out of its anchor and keyed a turn later so
    /// Escape and the arrows reach it (#2563, #2571).
    func showPanel(
        _ content: BarPeekContent,
        at anchor: Anchor,
        frame: CGRect,
        shelf: KiwiShelf,
        fades: Bool
    ) {
        guard let view = anchor.view, let window = view.window else {
            return
        }
        switch anchor.source.clickGrowth {
        case nil:
            panel.show(
                content,
                shelf: shelf,
                edge: anchor.edge,
                anchor: frame,
                strip: window.frame,
                visible: visibleArea(window),
                fades: fades
            )
            return
        case .fromPill:
            // The source is the one gate; an anchor that cannot grow
            // its list is a wiring defect, never a quiet fall back to
            // a hover peek the source's other readers would hold open.
            guard let grown = view as? any BarPeekMorphAnchor else {
                assertionFailure("a pill source on a non-morph anchor")
                dismiss()
                return
            }
            panel.showMorph(
                content,
                shelf: shelf,
                request: .init(anchor: grown, pill: frame, edge: anchor.edge),
                visible: visibleArea(window)
            )
        case .outOfItem:
            panel.showGrown(
                content,
                shelf: shelf,
                request: .init(
                    item: view,
                    frame: frame,
                    edge: anchor.edge,
                    strip: window.frame
                ),
                visible: visibleArea(window)
            )
        }
        schedule(0) { [weak self, weak view] in
            guard let self, let view, self.shown?.view === view,
                let key = self.panel.panel
            else { return }
            key.makeKey()
        }
    }
}
