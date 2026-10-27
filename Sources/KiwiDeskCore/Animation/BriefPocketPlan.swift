import CoreGraphics
import Foundation

/// The brief pocket's geometry and timeline (#2680): where the
/// pocket appears, and when it fades, nods and takes the plate.
/// Pure, so the placement and the sequence are unit-tested; the
/// overlay only draws what this decides. Frames are AX
/// coordinates (top-left origin), times seconds from the press.
enum BriefPocketPlan {
    /// Which way the plate flies.
    enum Direction: Equatable, Sendable {
        /// A window going into the pocket: the plate shrinks in.
        case into
        /// A window coming out: the plate grows out.
        case outOf
    }

    /// The pocket plate's side, KiwiShelf's default thickness.
    static let side: CGFloat = 40
    /// The pocket mark inside it, and the size the plate ends at.
    static let markSide: CGFloat = 26
    /// The pocket's distance from the edge, or from a bar on it.
    static let margin: CGFloat = 8
    /// The flying plate's corner radius at full size, the Space
    /// switch plate's.
    static let plateRadius = SpaceSlidePlan.cornerRadius

    static let fadeIn: TimeInterval = 0.12
    static let nod: TimeInterval = 0.18
    static let fadeOut: TimeInterval = 0.2
    /// The plate's own fade where it meets or leaves the pocket.
    static let plateFade: TimeInterval = 0.12
    /// How far the pocket swells at the top of its nod.
    static let nodScale: CGFloat = 1.15

    /// The flight's length at `durationMS`, the window duration:
    /// twice it, so the default 150 ms flies in 0.3 s.
    static func flight(durationMS: Int) -> TimeInterval {
        min(max(Double(durationMS) * 2 / 1000, 0.2), 0.8)
    }

    /// The pocket's frame in `region` — the screen's visible
    /// bounds clear of the bars — on `edge`, its centre `position`
    /// percent along it (left or top first), kept whole inside.
    static func pocketFrame(
        in region: CGRect,
        edge: AppBarEdge,
        position: CGFloat
    ) -> CGRect {
        let share = max(0, min(position, 100)) / 100
        let half = side / 2
        func along(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
            let lo = low + margin + half
            let hi = high - margin - half
            guard hi > lo else { return (low + high) / 2 }
            return min(max(low + (high - low) * share, lo), hi)
        }
        let centre: CGPoint
        switch edge {
        case .top:
            centre = CGPoint(
                x: along(region.minX, region.maxX),
                y: region.minY + margin + half
            )
        case .bottom:
            centre = CGPoint(
                x: along(region.minX, region.maxX),
                y: region.maxY - margin - half
            )
        case .left:
            centre = CGPoint(
                x: region.minX + margin + half,
                y: along(region.minY, region.maxY)
            )
        case .right:
            centre = CGPoint(
                x: region.maxX - margin - half,
                y: along(region.minY, region.maxY)
            )
        }
        return CGRect(
            x: centre.x - half,
            y: centre.y - half,
            width: side,
            height: side
        )
    }

    /// The square the plate ends at inside `pocket`, the mark's.
    static func markFrame(in pocket: CGRect) -> CGRect {
        pocket.insetBy(
            dx: (pocket.width - markSide) / 2,
            dy: (pocket.height - markSide) / 2
        )
    }

    /// One play's timeline.
    struct Timeline: Equatable, Sendable {
        /// When the plate starts to move.
        let flightBegin: TimeInterval
        /// When it reaches the pocket or the window's frame.
        let flightEnd: TimeInterval
        /// When the pocket nods.
        let nodBegin: TimeInterval
        /// When the pocket starts to fade out.
        let liftBegin: TimeInterval

        /// When the play is over and its panel may go dormant.
        var end: TimeInterval {
            max(liftBegin + BriefPocketPlan.fadeOut, flightEnd + plateFade)
        }

        private var plateFade: TimeInterval { BriefPocketPlan.plateFade }
    }

    /// Into the pocket, the plate flies at once over the parked
    /// window and the pocket nods as it lands; out of it, the
    /// pocket nods first and the plate grows out after.
    static func timeline(
        _ direction: Direction,
        flight: TimeInterval
    ) -> Timeline {
        switch direction {
        case .into:
            return Timeline(
                flightBegin: 0,
                flightEnd: flight,
                nodBegin: flight,
                liftBegin: flight + nod
            )
        case .outOf:
            return Timeline(
                flightBegin: fadeIn,
                flightEnd: fadeIn + flight,
                nodBegin: fadeIn,
                liftBegin: fadeIn + flight
            )
        }
    }

    /// The plate's frame `t` seconds in: `window` and the mark's
    /// square eased between, the plate redrawn at each size.
    static func plateFrame(
        at t: TimeInterval,
        direction: Direction,
        window: CGRect,
        pocket: CGRect,
        timeline: Timeline
    ) -> CGRect {
        let span = timeline.flightEnd - timeline.flightBegin
        let raw = span > 0 ? (t - timeline.flightBegin) / span : 1
        let p = CGFloat(ease(max(0, min(raw, 1))))
        let mark = markFrame(in: pocket)
        let (from, to) =
            direction == .into ? (window, mark) : (mark, window)
        return CGRect(
            x: from.minX + (to.minX - from.minX) * p,
            y: from.minY + (to.minY - from.minY) * p,
            width: from.width + (to.width - from.width) * p,
            height: from.height + (to.height - from.height) * p
        )
    }

    /// The plate's corner radius at `frame`: the switch plate's,
    /// down to the mark's rounding as it nears the mark's size.
    static func plateRadius(for frame: CGRect) -> CGFloat {
        min(plateRadius, min(frame.width, frame.height) * 0.22)
    }

    /// The plate's opacity `t` seconds in: it fades where it meets
    /// the pocket — on landing into it, on leaving out of it — and
    /// out of the pocket fades again once it covers the window.
    static func plateOpacity(
        at t: TimeInterval,
        direction: Direction,
        timeline: Timeline
    ) -> CGFloat {
        switch direction {
        case .into:
            return 1 - ramp(t, from: timeline.flightEnd, by: plateFade)
        case .outOf:
            return ramp(t, from: timeline.flightBegin, by: plateFade)
                * (1 - ramp(t, from: timeline.flightEnd, by: plateFade))
        }
    }

    /// The pocket's opacity `t` seconds in: it fades in from the
    /// press and out from the lift.
    static func pocketOpacity(
        at t: TimeInterval,
        timeline: Timeline
    ) -> CGFloat {
        ramp(t, from: 0, by: fadeIn)
            * (1 - ramp(t, from: timeline.liftBegin, by: fadeOut))
    }

    /// The pocket's frame `t` seconds in: `pocket`, swollen about
    /// its centre by the nod and redrawn at that size.
    static func pocketFrame(
        _ pocket: CGRect,
        at t: TimeInterval,
        timeline: Timeline
    ) -> CGRect {
        let u = ramp(t, from: timeline.nodBegin, by: nod)
        let swell = (nodScale - 1) * CGFloat(sin(Double.pi * Double(u)))
        let grow = pocket.width * swell / 2
        return pocket.insetBy(dx: -grow, dy: -grow)
    }

    /// The app icon's side on a plate of `frame`: the switch
    /// plate's share of a large plate, and most of a small one so
    /// the icon still reads at the mark's size.
    static func iconSide(on frame: CGRect) -> CGFloat {
        let short = min(frame.width, frame.height)
        let share = SpaceSlidePlan.iconShare * short
        return min(
            max(share, min(short * 0.7, SpaceSlidePlan.iconMinimum)),
            SpaceSlidePlan.iconMaximum
        )
    }

    /// 0 before `from`, 1 after `from + by`, linear between.
    private static func ramp(
        _ t: TimeInterval,
        from: TimeInterval,
        by: TimeInterval
    ) -> CGFloat {
        guard by > 0 else { return t >= from ? 1 : 0 }
        return CGFloat(max(0, min((t - from) / by, 1)))
    }

    /// Ease-in-out cubic.
    static func ease(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}
