import AppKit

/// A hiding shelf's reveal and retract (#761): its plate grows out
/// of the hidden mark and its items fade up on it, and back,
/// through `BarMotion.playReveal`, each taking over from where the
/// other stands, the panel ordered out only once the retract lands.
extension ShelfOverlay {
    /// Where the hidden mark sits in the content, from its frame
    /// and the shelf's strip, both AX coordinates.
    func setRevealOrigin(mark: CGRect?, strip: CGRect) {
        guard let mark else {
            revealOrigin = nil
            return
        }
        let local = mark.offsetBy(dx: -strip.minX, dy: -strip.minY)
        revealOrigin =
            content.isFlipped
            ? local
            : CGRect(
                x: local.minX,
                y: strip.height - local.maxY,
                width: local.width,
                height: local.height
            )
    }

    /// The mark, or the middle of the content where none is known.
    private var origin: CGRect {
        revealOrigin
            ?? CGRect(x: content.bounds.midX, y: 0, width: 0, height: 0)
    }

    /// Grows the content out of the mark; a retract in flight is
    /// taken back from where it stands. A reveal `ordering` the
    /// panel in stands at the mark through the pass that orders it
    /// in — that commit also draws every section for the first
    /// time — and starts in the next, after a short lead
    /// (`BarMotion.revealLead`), so no frame of its travel plays
    /// before the panel is on screen.
    func revealIn(ordering: Bool = false) {
        // A reveal takes the shelf back from a leave in flight.
        leaving = nil
        leavingSlides = false
        content.alphaValue = 1
        let token = UUID()
        revealing = token
        guard ordering else {
            land(token, after: start(lead: false))
            return
        }
        BarMotion.playReveal(
            content,
            items: stripView,
            origin: origin,
            plate: revealPlate,
            entering: true,
            held: true
        )
        afterCommit { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.land(token, after: self.start(lead: true))
        }
    }

    private func start(lead: Bool) -> TimeInterval {
        BarMotion.playReveal(
            content,
            items: stripView,
            origin: origin,
            plate: revealPlate,
            entering: true,
            lead: lead
        )
    }

    /// Ends the reveal `token` started once it has landed, unless
    /// a newer reveal or a leave took the shelf meanwhile.
    private func land(_ token: UUID, after span: TimeInterval) {
        afterReveal(span) { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.revealing = nil
            BarMotion.endReveal(self.content, items: self.stripView)
        }
    }

    /// Shrinks the content back into the mark and orders the panel
    /// out once it lands, unless a show meanwhile took the shelf
    /// back. Returns whether this call began the leave.
    func retractOut() -> Bool {
        guard leaving == nil else { return false }
        let token = UUID()
        leaving = token
        leavingSlides = true
        // The managers hid the sections; the shelf draws them on
        // until the retract lands, as its fade does (#1838).
        for view in stripView.subviews
        where view !== divider && view !== handle {
            view.isHidden = false
        }
        revealing = nil
        let span = BarMotion.playReveal(
            content,
            items: stripView,
            origin: origin,
            plate: revealPlate,
            entering: false
        )
        afterReveal(span) { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.leavingSlides = false
            self.panel?.orderOut(nil)
            BarMotion.endReveal(self.content, items: self.stripView)
            self.onLeft()
        }
        return true
    }
}
