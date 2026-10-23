import AppKit

/// The overflow mark's list (#2563 ▸ Ruling): the one peek, grown
/// out of its anchor and held open by a click alone.
extension BarPeek {
    /// A list held open by a click (#2563) closes: a Desktop switch
    /// or KiwiVision turning on or off makes it stale.
    func dismissHeld() {
        guard shown?.source.morphsFromAnchor == true else { return }
        dismiss()
    }

    /// The panel shown for `anchor` framed `frame`: a list grown out
    /// of its anchor, keyed a turn later so Escape and the arrows
    /// reach it (#2563), or the bar's peek.
    func showPanel(
        _ content: BarPeekContent,
        at anchor: Anchor,
        frame: CGRect,
        shelf: KiwiShelf,
        fades: Bool
    ) {
        guard let window = anchor.view?.window else { return }
        guard anchor.source.morphsFromAnchor else {
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
        }
        // The flag is the one gate; an anchor that cannot grow its
        // list is a wiring defect, never a quiet fall back to a
        // hover peek the flag's other readers would hold open.
        guard let grown = anchor.view as? any BarPeekMorphAnchor else {
            assertionFailure("a morphing source on a non-morph anchor")
            dismiss()
            return
        }
        panel.showMorph(
            content,
            shelf: shelf,
            request: .init(anchor: grown, pill: frame, edge: anchor.edge),
            visible: visibleArea(window)
        )
        schedule(0) { [weak self, weak grown] in
            guard let self, let grown, self.shown?.view === grown,
                let key = self.panel.panel
            else { return }
            key.makeKey()
        }
    }
}
