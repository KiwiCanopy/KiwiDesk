import AppKit

/// A revealed shelf's reveal and retract (#761, #2497): the whole
/// shelf slides in from its screen side, laid out, grows out of its
/// mark or stretches out of it as an unfold — the shelf's
/// `reveal_style` — and back, through
/// `BarMotion.playReveal`, each taking over from where the other
/// stands, the panel ordered out only once the retract lands. The
/// panel stays still and the content moves inside its room.
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

    /// What the reveal plays along: the shelf's reveal kind — its
    /// `reveal_style`, an unfold with no plate spreading, the one
    /// verdict its mark reads too — the slide's start past the
    /// strip's screen side and the margin, the grow's and the
    /// unfold's mark (the middle of the screen side where the edge
    /// draws none, a Hidden bar's) and plate. A shelf not yet shown
    /// fades.
    var revealPath: BarMotion.RevealPath {
        guard let drawn else { return .init(kind: .fade) }
        let strip = drawn.strip
        return BarMotion.RevealPath(
            kind: BarMotion.RevealKind(drawn.shelf),
            offset: BarMotion.revealOffset(
                edge: drawn.edge,
                depth: drawn.edge.isHorizontal ? strip.height : strip.width,
                gap: revealGap
            ),
            origin: revealOrigin
                ?? Self.screenSide(of: restRoom, edge: drawn.edge),
            plate: revealPlate?.frame,
            plateRadius: revealPlate?.radius ?? 0,
            horizontal: drawn.edge.isHorizontal
        )
    }

    /// The middle of `rest`'s screen side, as a point-sized rect in
    /// the content's flipped coordinates.
    nonisolated static func screenSide(
        of rest: CGRect,
        edge: AppBarEdge
    ) -> CGRect {
        let point: CGPoint
        switch edge {
        case .top: point = CGPoint(x: rest.midX, y: rest.minY)
        case .bottom: point = CGPoint(x: rest.midX, y: rest.maxY)
        case .left: point = CGPoint(x: rest.minX, y: rest.midY)
        case .right: point = CGPoint(x: rest.maxX, y: rest.midY)
        }
        return CGRect(origin: point, size: .zero)
    }

    /// Where the content starts a slide from, in its own
    /// coordinates; zero before a show.
    var revealOffset: CGVector { revealPath.offset }

    /// The strip's distance to the usable area's edge — the outer
    /// margin — which the slide crosses and its room covers.
    var revealGap: CGFloat { drawn?.shelf.outerMargin ?? 0 }

    /// A leave that is no slide cuts a reveal short: it never lands,
    /// so its motion and its token end here.
    func cutReveal() {
        revealing = nil
        growing = false
        BarMotion.endReveal(content, items: stripView)
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
        openRevealRoom(entering: true)
        guard ordering else {
            land(token, after: start(lead: false, from: from))
            return
        }
        BarMotion.playReveal(
            content,
            items: stripView,
            path: revealPath,
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
            items: stripView,
            path: revealPath,
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
            self.growing = false
            BarMotion.endReveal(self.content, items: self.stripView)
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
        openRevealRoom(entering: false)
        let span = BarMotion.playReveal(
            content,
            items: stripView,
            path: revealPath,
            entering: false,
            from: from
        )
        afterReveal(span) { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.leavingSlides = false
            self.growing = false
            self.panel?.orderOut(nil)
            BarMotion.endReveal(self.content, items: self.stripView)
            self.onLeft()
        }
        return true
    }
}
