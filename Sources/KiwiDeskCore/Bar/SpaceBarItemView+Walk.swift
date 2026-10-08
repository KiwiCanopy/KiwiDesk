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
    /// badges start where `walk.travel` puts them, the glyphs
    /// brought in from transparent, and the glyphs carried off
    /// travel on and fade out under their disc, leaving when the
    /// walk lands; none travels outside the chip's cells (#2052).
    /// All through `BarMotion.playWalk`, whose offsets a later
    /// layout pass cannot cancel; a pass with no walk pending
    /// leaves one in flight alone.
    func slideGlyphs(pitch: CGFloat) {
        guard let walk = pendingWalk else { return }
        pendingWalk = nil
        let leaving = leavingViews
        let lead = before.windows.isEmpty ? 0 : 1
        let cellCount =
            lead + appViews.count + (after.windows.isEmpty ? 0 : 1)
        let along = { (cells: Int) -> CGVector in
            let by = CGFloat(cells) * pitch
            return self.horizontal
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
            let travel = walk.travel(
                resting: lead + index,
                cellCount: cellCount
            )
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
                        slide: along(travel.from - travel.to),
                        fade: arrives ? -view.alphaValue : 0
                    )
                )
            }
        }
        let rests = Self.leavingRests(
            walk,
            lead: lead,
            drawn: appViews.count,
            leaving: leaving.count
        )
        for (view, rest) in zip(leaving, rests) {
            let travel = walk.travel(resting: rest, cellCount: cellCount)
            let alpha = view.alphaValue
            let to = along(travel.to - travel.from)
            view.frame = view.frame.offsetBy(dx: to.dx, dy: to.dy)
            view.alphaValue = 0
            steps.append(
                .init(
                    view: view,
                    slide: along(travel.from - travel.to),
                    fade: alpha
                )
            )
        }
        BarMotion.playWalk(steps) { [weak self] in
            leaving.forEach { $0.removeFromSuperview() }
            self?.leavingViews.removeAll { view in
                leaving.contains { $0 === view }
            }
        }
    }

    /// The cells the glyphs `leaving(_:walk:)` carries off would
    /// take in the new strip of `drawn` glyphs, in its order: the
    /// front ones just ahead of its first glyph, the back ones
    /// just past its last.
    static func leavingRests(
        _ walk: SpaceBarStrip.Walk,
        lead: Int,
        drawn: Int,
        leaving count: Int
    ) -> [Int] {
        let front = min(walk.leavingFront, count)
        let back = count - front
        let skipped = max(walk.leavingBack - back, 0)
        return (0..<front).map { lead - walk.leavingFront + $0 }
            + (0..<back).map { lead + drawn + skipped + $0 }
    }
}
