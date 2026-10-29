import AppKit
import QuartzCore

/// The pocket rising out of its handle (#2678, 2026-10-29 ruling):
/// lift, grow from the handle's kiwis and, on another edge, the turn
/// upright, all one transform on one damped spring pivoting on the
/// pocket's base behind the tab. Under Reduce Motion it stands out
/// at once.
extension BarMotion {
    /// How far below its risen place the pocket starts, past the
    /// tab, so the kiwis are what first shows.
    @MainActor static var pocketRiseTravel: CGFloat {
        PocketHandleView.tabDepth + PocketPlateView.lift
            + PocketHandleView.markSide - PocketHandleView.lookOut
    }

    /// Plays the rise on `pocket`, `side` points risen on `edge`.
    @MainActor
    static func playPocketRise(
        _ pocket: BriefPocketView,
        edge: AppBarEdge,
        side: CGFloat
    ) {
        guard
            let rise = pocketRise(
                edge: edge,
                side: side,
                reduceMotion: isReduced
            ),
            let layer = pocket.layer
        else { return }
        layer.add(rise, forKey: "pocketRise")
    }

    /// The rise's spring, nil under `reduceMotion` or with no side.
    @MainActor
    static func pocketRise(
        edge: AppBarEdge,
        side: CGFloat,
        reduceMotion: Bool
    ) -> CASpringAnimation? {
        guard !reduceMotion, side > 0 else { return nil }
        let animation = CASpringAnimation(keyPath: "transform")
        animation.fromValue = NSValue(
            caTransform3D: pocketRiseStart(edge: edge, side: side)
        )
        animation.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        // Critically damped: no overshoot to read as a throb.
        animation.mass = 1
        animation.stiffness = 220
        animation.damping = 2 * (220 as CGFloat).squareRoot()
        animation.duration = animation.settlingDuration
        return animation
    }

    /// Where the rise starts, in the pocket layer's own flipped
    /// coordinates: scaled to the handle's kiwis about its base,
    /// turned with its edge and dropped behind the tab.
    @MainActor
    static func pocketRiseStart(
        edge: AppBarEdge,
        side: CGFloat
    ) -> CATransform3D {
        let travel = pocketRiseTravel
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
