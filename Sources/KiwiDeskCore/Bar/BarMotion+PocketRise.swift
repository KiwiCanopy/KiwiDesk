import AppKit
import QuartzCore

/// The pocket rising out of its handle (#2678, 2026-10-29 ruling):
/// lift, grow from the handle's kiwis and, on another edge, the turn
/// upright, all one transform pivoting on the pocket's base behind
/// the tab. Its approach scrubs it up as a countdown and a leave
/// sinks it back from where it stands, one animation each (#3368);
/// a stand ahead of the countdown finishes on a damped spring. Every
/// transition reads where the pocket is drawn, removes the running
/// animation and adds one lasting the distance left times its pace
/// (#3383). Under
/// Reduce Motion it stands out at once. The One-window pocket, which
/// has no handle, slides out of its edge instead (#2793,
/// `BarMotion+PocketEntrance`).
extension BarMotion {
    /// How far below its risen place the pocket starts, past the
    /// tab, so the kiwis are what first shows — as far as they look
    /// out while the pocket `holds` something or not (#3446), past
    /// a tab `tabDepth` deep (#3451). The motion members take this
    /// distance as `travel`.
    @MainActor static func pocketRiseTravel(
        holds: Bool,
        tabDepth: CGFloat
    ) -> CGFloat {
        tabDepth + PocketPlateView.lift
            + PocketHandleView.markSide
            - PocketHandleView.lookOut(holds: holds)
    }

    /// The key the rise, its countdown and its sink run under, so
    /// each takes over from the last.
    static let pocketRiseKey = "pocketRise"

    /// Where `pocket`'s rise stands on screen, nil where none runs;
    /// a layer not yet drawn stands where its animation starts.
    @MainActor
    static func pocketRiseShown(_ pocket: BriefPocketView) -> CATransform3D? {
        guard let layer = pocket.layer,
            let running = layer.animation(forKey: pocketRiseKey)
        else { return nil }
        if let shown = layer.presentation() { return shown.transform }
        return (running.value(forKey: "fromValue") as? NSValue)?
            .caTransform3DValue
    }

    /// Plays the rise on `pocket`, `side` points risen on `edge`,
    /// from where a countdown or a sink left it.
    @MainActor
    static func playPocketRise(
        _ pocket: BriefPocketView,
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        up: Bool = false
    ) {
        guard let layer = pocket.layer else { return }
        // A rise drawn up with no animation left stands risen.
        let from =
            pocketRiseShown(pocket) ?? (up ? CATransform3DIdentity : nil)
        layer.removeAnimation(forKey: pocketRiseKey)
        guard
            let rise = pocketRise(
                edge: edge,
                side: side,
                travel: travel,
                from: from,
                reduceMotion: isReduced
            )
        else { return }
        layer.add(rise, forKey: pocketRiseKey)
    }

    /// The rise's spring from `from`, else from the handle's kiwis;
    /// nil under `reduceMotion` or with no side.
    @MainActor
    static func pocketRise(
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        from: CATransform3D? = nil,
        reduceMotion: Bool
    ) -> CASpringAnimation? {
        guard !reduceMotion, side > 0 else { return nil }
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = NSValue(
            caTransform3D: from
                ?? pocketRiseStart(edge: edge, side: side, travel: travel)
        )
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        // Critically damped: no overshoot to read as a throb.
        animation.mass = 1
        animation.stiffness = 220
        animation.damping = 2 * (220 as CGFloat).squareRoot()
        animation.duration = animation.settlingDuration
        return animation
    }

    /// Whether the pocket's approach scrubs its rise: not under
    /// Reduce Motion, where it stands when the dwell ends, nor under
    /// KiwiDesk's Off (#3368 ruling 4). Starts no motion.
    @MainActor static var pocketScrubs: Bool {
        !isReduced && revealLength > 0
    }

    /// Scrubs `pocket` up on `rise`, from where a running rise
    /// stands, or from the handle's kiwis after `rise`'s delay.
    @MainActor
    static func playPocketScrub(
        _ pocket: BriefPocketView,
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        rise: ShelfHandleSpec.Fill,
        pace: TimeInterval
    ) {
        guard let layer = pocket.layer else { return }
        let from = pocketRiseShown(pocket)
        guard
            let scrub = pocketScrub(
                edge: edge,
                side: side,
                travel: travel,
                rise: rise,
                pace: pace,
                from: from,
                reduceMotion: isReduced
            )
        else {
            // Already up, or not drawn: what runs stays, so a later
            // rise or sink reads it where it is.
            return
        }
        layer.removeAnimation(forKey: pocketRiseKey)
        if scrub.beginTime > 0 {
            scrub.beginTime += layer.convertTime(
                CACurrentMediaTime(),
                from: nil
            )
        }
        layer.add(scrub, forKey: pocketRiseKey)
    }

    /// The countdown's scrub, from `from` — where the pocket is
    /// drawn, nil at the handle's kiwis — to risen, lasting the
    /// distance left times `pace`, a whole rise's; still over `rise`'s delay
    /// only while nothing has risen yet. Nil under `reduceMotion`,
    /// with no side, or already risen. `beginTime` is the delay,
    /// relative.
    @MainActor
    static func pocketScrub(
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        rise: ShelfHandleSpec.Fill,
        pace: TimeInterval,
        from: CATransform3D?,
        reduceMotion: Bool
    ) -> CABasicAnimation? {
        guard !reduceMotion, side > 0 else { return nil }
        let start = pocketRiseStart(
            edge: edge,
            side: side,
            travel: travel
        )
        let shown = from ?? start
        let done = PocketRiseTimeline.progress(shown: shown, start: start)
        let delay = done > 0 ? 0 : PocketRiseTimeline.delay(of: rise)
        let length = (1 - done) * pace
        guard length > 0.001 else { return nil }
        let scrub = CABasicAnimation(keyPath: "transform")
        scrub.fromValue = NSValue(caTransform3D: shown)
        scrub.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        scrub.beginTime = delay
        scrub.duration = length
        scrub.timingFunction = CAMediaTimingFunction(name: .linear)
        scrub.fillMode = .both
        scrub.isRemovedOnCompletion = false
        return scrub
    }

    /// How long a sink from a whole rise takes.
    static let pocketSinkSpan: TimeInterval = 0.2

    /// Sinks `pocket` back into its handle from where its rise
    /// stands — risen where none runs and `risen` — and returns how
    /// long that takes, 0 where nothing is up to sink.
    @MainActor
    @discardableResult
    static func playPocketSink(
        _ pocket: BriefPocketView,
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        risen: Bool = false
    ) -> TimeInterval {
        guard let layer = pocket.layer,
            let from = pocketRiseShown(pocket)
                ?? (risen ? CATransform3DIdentity : nil)
        else { return 0 }
        layer.removeAnimation(forKey: pocketRiseKey)
        guard
            let sink = pocketSink(
                edge: edge,
                side: side,
                travel: travel,
                from: from,
                reduceMotion: isReduced
            )
        else { return 0 }
        layer.add(sink, forKey: pocketRiseKey)
        return sink.duration
    }

    /// The sink from `from` back to the handle's kiwis, lasting the
    /// distance up times `pocketSinkSpan`, held there until its
    /// landing removes it; nil under `reduceMotion`, with no side, or
    /// with nothing up.
    @MainActor
    static func pocketSink(
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat,
        from: CATransform3D,
        reduceMotion: Bool
    ) -> CABasicAnimation? {
        guard !reduceMotion, side > 0 else { return nil }
        let start = pocketRiseStart(
            edge: edge,
            side: side,
            travel: travel
        )
        let up = PocketRiseTimeline.progress(shown: from, start: start)
        guard up > 0.001 else { return nil }
        let sink = CABasicAnimation(keyPath: "transform")
        sink.fromValue = NSValue(caTransform3D: from)
        sink.toValue = NSValue(caTransform3D: start)
        sink.duration = up * pocketSinkSpan
        sink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        sink.fillMode = .forwards
        sink.isRemovedOnCompletion = false
        return sink
    }

    /// Where the rise starts, in the pocket layer's own flipped
    /// coordinates: scaled to the handle's kiwis about its base,
    /// turned with its edge and dropped behind the tab.
    @MainActor
    static func pocketRiseStart(
        edge: AppBarEdge,
        side: CGFloat,
        travel: CGFloat
    ) -> CATransform3D {
        let pivot: CGPoint
        let drop: CGPoint
        switch edge {
        case .bottom:
            pivot = CGPoint(x: side / 2, y: side)
            drop = CGPoint(x: 0, y: travel)
        case .top:
            pivot = CGPoint(x: side / 2, y: 0)
            drop = CGPoint(x: 0, y: -travel)
        case .left:
            pivot = CGPoint(x: 0, y: side / 2)
            drop = CGPoint(x: -travel, y: 0)
        case .right:
            pivot = CGPoint(x: side, y: side / 2)
            drop = CGPoint(x: travel, y: 0)
        }
        let scale = PocketHandleView.markSide / side
        var t = CATransform3DMakeTranslation(
            drop.x + pivot.x,
            drop.y + pivot.y,
            0
        )
        t = CATransform3DRotate(t, PocketHandleView.turn(for: edge), 0, 0, 1)
        t = CATransform3DScale(t, scale, scale, 1)
        return CATransform3DTranslate(t, -pivot.x, -pivot.y, 0)
    }
}
