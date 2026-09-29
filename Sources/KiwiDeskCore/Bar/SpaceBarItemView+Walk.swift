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

    /// Walks the glyphs in from where they drew when the strip
    /// moved (#1528 item 21): each glyph and its badges start
    /// `walk.cells` cells along and travel to their cells; the
    /// glyphs it carries off fade out under their disc and those
    /// it brings fade in. All through `BarMotion`, which lands
    /// them at once under Reduce Motion.
    func slideGlyphs(pitch: CGFloat) {
        let walk = pendingWalk
        pendingWalk = nil
        let leaving = leavingViews
        guard let walk else {
            leaving.forEach { $0.removeFromSuperview() }
            leavingViews = []
            return
        }
        let shift = CGFloat(walk.cells) * pitch
        let moving: [NSView] =
            appViews + badgeViews + stickyBadgeViews
            + floatingBadgeViews
        let front = min(walk.enteringFront, appViews.count)
        let back = min(walk.enteringBack, appViews.count - front)
        let entering =
            Array(appViews.prefix(front)) + Array(appViews.suffix(back))
        let along = { (frame: CGRect, by: CGFloat) -> CGRect in
            self.horizontal
                ? frame.offsetBy(dx: by, dy: 0)
                : frame.offsetBy(dx: 0, dy: by)
        }
        BarMotion.runLayout(
            {
                for view in moving where !view.isHidden {
                    let final = view.frame
                    view.frame = along(final, shift)
                    BarMotion.setFrame(view, to: final, animated: true)
                }
                for view in entering {
                    view.alphaValue = 0
                    BarMotion.setAlpha(view, to: 1)
                }
                for view in leaving {
                    BarMotion.setFrame(
                        view,
                        to: along(view.frame, -shift),
                        animated: true
                    )
                    BarMotion.setAlpha(view, to: 0)
                }
            },
            completion: { [weak self] in
                leaving.forEach { $0.removeFromSuperview() }
                self?.leavingViews.removeAll { view in
                    leaving.contains { $0 === view }
                }
            }
        )
    }
}
