import AppKit

/// A Space chip's strip walk (#1528 item 21): when the strip
/// moves under a Space the chip kept, its glyphs travel by whole
/// cells, the ones it carries off fading under their disc and
/// the ones it brings fading in.
extension SpaceBarItemView {
    /// The glyphs `walk` carries off each end.
    static func leaving(
        _ views: [NSView],
        walk: SpaceBarStrip.Walk?
    ) -> [NSView] {
        guard let walk else { return [] }
        let front = min(walk.leavingFront, views.count)
        let back = min(walk.leavingBack, views.count - front)
        return Array(views.prefix(front)) + Array(views.suffix(back))
    }

    /// Plays the pending walk from the frames and alphas this
    /// layout pass just wrote (#1528 item 21): each glyph and its
    /// badges start `walk.cells` cells along, the glyphs brought
    /// in from transparent, and the glyphs carried off travel on
    /// and fade out under their disc, leaving when the walk lands.
    /// All through `BarMotion.playWalk`, whose offsets a later
    /// layout pass cannot cancel; a pass with no walk pending
    /// leaves one in flight alone.
    func slideGlyphs(pitch: CGFloat) {
        guard let walk = pendingWalk else { return }
        pendingWalk = nil
        let leaving = leavingViews
        let shift = CGFloat(walk.cells) * pitch
        let along = { (by: CGFloat) -> CGVector in
            self.horizontal
                ? CGVector(dx: by, dy: 0) : CGVector(dx: 0, dy: by)
        }
        let front = min(walk.enteringFront, appViews.count)
        let back = min(walk.enteringBack, appViews.count - front)
        let entering = Set(
            Array(0..<front)
                + Array((appViews.count - back)..<appViews.count)
        )
        var steps: [BarMotion.WalkStep] = []
        for (index, glyph) in appViews.enumerated() {
            let arrives = entering.contains(index)
            let badges: [[NSView?]] = [
                badgeViews, stickyBadgeViews, floatingBadgeViews,
            ]
            let parts =
                [glyph]
                + badges.compactMap {
                    $0.indices.contains(index) ? $0[index] : nil
                }
            for view in parts where !view.isHidden {
                steps.append(
                    .init(
                        view: view,
                        slide: along(shift),
                        fade: arrives ? -view.alphaValue : 0
                    )
                )
            }
        }
        for view in leaving {
            let alpha = view.alphaValue
            let to = along(-shift)
            view.frame = view.frame.offsetBy(dx: to.dx, dy: to.dy)
            view.alphaValue = 0
            steps.append(
                .init(view: view, slide: along(shift), fade: alpha)
            )
        }
        BarMotion.playWalk(steps) { [weak self] in
            leaving.forEach { $0.removeFromSuperview() }
            self?.leavingViews.removeAll { view in
                leaving.contains { $0 === view }
            }
        }
    }
}
