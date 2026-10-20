import AppKit

/// A hiding shelf's reveal and retract (#761, #2497): the whole
/// shelf slides in from its screen side, laid out, and back out,
/// through `BarMotion.playReveal`, each taking over from where the
/// other stands, the panel ordered out only once the retract lands.
/// The panel stays still and the content slides inside its room.
extension ShelfOverlay {
    /// Where the content starts a slide from, in its own
    /// coordinates: past the strip's screen side and the margin to
    /// the usable area's edge. Zero before a show, which fades.
    var revealOffset: CGVector {
        guard let drawn else { return .zero }
        let strip = drawn.strip
        return BarMotion.revealOffset(
            edge: drawn.edge,
            depth: drawn.edge.isHorizontal ? strip.height : strip.width,
            gap: revealGap
        )
    }

    /// The strip's distance to the usable area's edge — the outer
    /// margin — which the slide crosses and its room covers.
    var revealGap: CGFloat { drawn?.shelf.outerMargin ?? 0 }

    /// A leave that is no slide cuts a reveal short: it never lands,
    /// so its motion and its token end here.
    func cutReveal() {
        revealing = nil
        BarMotion.endReveal(content)
    }

    /// Slides the content in; a retract in flight is taken back
    /// from where it stands. A reveal `ordering` the panel in
    /// stands at its start through the pass that orders it in —
    /// that commit also draws every section for the first time —
    /// and starts in the next, after a short lead
    /// (`BarMotion.revealLead`), so no frame of its travel plays
    /// before the panel is on screen.
    /// `from` is a slide in flight, read before this pass moved the
    /// room; nil reads it now.
    func revealIn(ordering: Bool = false, from: CGPoint? = nil) {
        let from = from ?? BarMotion.revealShift(of: content)
        // A reveal takes the shelf back from a leave in flight.
        leaving = nil
        leavingSlides = false
        content.alphaValue = 1
        let token = UUID()
        revealing = token
        openSlideRoom()
        guard ordering else {
            land(token, after: start(lead: false, from: from))
            return
        }
        BarMotion.playReveal(
            content,
            offset: revealOffset,
            entering: true,
            from: from,
            held: true
        )
        afterCommit { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.land(token, after: self.start(lead: true))
        }
    }

    private func start(lead: Bool, from: CGPoint? = nil) -> TimeInterval {
        BarMotion.playReveal(
            content,
            offset: revealOffset,
            entering: true,
            from: from,
            lead: lead
        )
    }

    /// Ends the reveal `token` started once it has landed, unless
    /// a newer reveal or a leave took the shelf meanwhile, and
    /// settles the panel's room.
    private func land(_ token: UUID, after span: TimeInterval) {
        afterReveal(span) { [weak self] in
            guard let self, self.revealing == token, self.leaving == nil
            else { return }
            self.revealing = nil
            BarMotion.endReveal(self.content)
            self.settleRoom()
        }
    }

    /// Slides the content back out and orders the panel out once it
    /// lands, unless a show meanwhile took the shelf back. Returns
    /// whether this call began the leave.
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
        let from = BarMotion.revealShift(of: content)
        openSlideRoom()
        let span = BarMotion.playReveal(
            content,
            offset: revealOffset,
            entering: false,
            from: from
        )
        afterReveal(span) { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.leavingSlides = false
            self.panel?.orderOut(nil)
            BarMotion.endReveal(self.content)
            self.onLeft()
        }
        return true
    }
}
