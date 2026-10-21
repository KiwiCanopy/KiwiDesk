import CoreGraphics
import Foundation

/// The unfold, the third `reveal_style` (owner ruling, 2026-10-21):
/// on a plate the clip stretches out of the mark along the edge,
/// then deepens to the plate while the items rise on it; under
/// Boxed each box springs out of the mark to its slot (the
/// spread). Its timings — the owner's device demo's numbers — and
/// its pure decisions; `BarMotion.playReveal`, the one home, plays
/// it.
enum ShelfUnfold {
    /// A plate unfold's channels: the clip from `mark` through
    /// `along` to `plate`, in the content layer's own coordinates.
    struct Stretch: Equatable {
        let entering: Bool
        let mark: CGRect
        /// The mark stretched to the plate's length at its own
        /// depth — the first stage's end, the retract's middle.
        let along: CGRect
        let plate: CGRect
        let markRadius: CGFloat
        let plateRadius: CGFloat
        let horizontal: Bool
        /// Until every channel has landed.
        let length: TimeInterval
    }

    /// A Boxed unfold: each box springs out of `mark`, the mark's
    /// centre in the content's coordinates, staggered by its
    /// distance along the edge over the run's `span`.
    struct Spread: Equatable {
        let entering: Bool
        let mark: CGPoint
        let span: CGFloat
        let horizontal: Bool
        let length: TimeInterval
    }

    /// The stretch along the edge: a spring of `alongDuration`
    /// with `alongBounce`.
    static let alongDuration: TimeInterval = 0.38
    static let alongBounce: CGFloat = 0.12
    /// The deepening, `deepenDelay` after the stretch starts.
    static let deepenDelay: TimeInterval = 0.16
    static let deepenDuration: TimeInterval = 0.32
    static let deepenBounce: CGFloat = 0
    /// The items rise — fade in and scale up from `itemsScale` —
    /// over `itemsFadeIn` from `itemsDelay`.
    static let itemsDelay: TimeInterval = 0.14
    static let itemsFadeIn: TimeInterval = 0.18
    static let itemsScale: CGFloat = 0.96
    /// The mark fades out over the reveal's first `markFadeOut`.
    static let markFadeOut: TimeInterval = 0.10
    /// A retract: the items out over `itemsFadeOut`, then the clip
    /// back through `along` to the mark over `collapse` from
    /// `collapseDelay`, reaching `along` at `alongKeyTime`.
    static let itemsFadeOut: TimeInterval = 0.08
    static let collapseDelay: TimeInterval = 0.06
    static let collapse: TimeInterval = 0.30
    static let alongKeyTime: Double = 0.47
    static let retractLength = collapseDelay + collapse

    /// The spread: each box from `spreadScale` at the mark to its
    /// slot, a spring of `spreadDuration` with `spreadBounce`,
    /// staggered up to `spreadStagger` by distance, fading in over
    /// `spreadFade`.
    static let spreadDuration: TimeInterval = 0.42
    static let spreadBounce: CGFloat = 0.15
    static let spreadScale: CGFloat = 0.4
    static let spreadStagger: TimeInterval = 0.08
    static let spreadFade: TimeInterval = 0.12
    /// The gather back: ease-in over `gather`, the outer boxes
    /// first by up to `gatherStagger`, each fading from
    /// `gatherFadeDelay` after its start over `spreadFade`.
    static let gather: TimeInterval = 0.26
    static let gatherStagger: TimeInterval = 0.05
    static let gatherFadeDelay: TimeInterval = 0.14
    static let gatherLength = gatherStagger + gather
    /// The mark fades out over the spread's first `markSpreadOut`.
    static let markSpreadOut: TimeInterval = 0.08

    /// `mark` stretched to `plate`'s length along the edge, at its
    /// own depth.
    static func along(
        mark: CGRect,
        plate: CGRect,
        horizontal: Bool
    ) -> CGRect {
        horizontal
            ? CGRect(
                x: plate.minX,
                y: mark.minY,
                width: plate.width,
                height: mark.height
            )
            : CGRect(
                x: mark.minX,
                y: plate.minY,
                width: mark.width,
                height: plate.height
            )
    }

    /// The unfold out of or into `mark` — at its hovered size,
    /// which `BarMotion.revealMotion` hands it — onto `plate`.
    static func stretch(
        entering: Bool,
        mark: CGRect,
        plate: CGRect,
        plateRadius: CGFloat,
        horizontal: Bool
    ) -> Stretch {
        let enter = max(
            alongDuration,
            deepenDelay + deepenDuration,
            itemsDelay + itemsFadeIn
        )
        return Stretch(
            entering: entering,
            mark: mark,
            along: along(mark: mark, plate: plate, horizontal: horizontal),
            plate: plate,
            markRadius: min(mark.width, mark.height) / 2,
            plateRadius: plateRadius,
            horizontal: horizontal,
            length: entering ? enter : retractLength
        )
    }

    /// The spread out of or into `mark`'s centre over a run `span`
    /// long along the edge.
    static func spread(
        entering: Bool,
        mark: CGRect,
        span: CGFloat,
        horizontal: Bool
    ) -> Spread {
        Spread(
            entering: entering,
            mark: CGPoint(x: mark.midX, y: mark.midY),
            span: span,
            horizontal: horizontal,
            length: entering ? spreadStagger + spreadDuration : gatherLength
        )
    }

    /// When a box `distance` from the mark along the edge starts: a
    /// spread's farther boxes later, a gather's sooner.
    static func delay(
        distance: CGFloat,
        span: CGFloat,
        entering: Bool
    ) -> TimeInterval {
        let share = span > 0 ? min(max(abs(distance) / span, 0), 1) : 0
        return entering
            ? Double(share) * spreadStagger
            : Double(1 - share) * gatherStagger
    }

    /// How far past its target a spring of `bounce` travels, as a
    /// share of its travel: an under-damped spring of damping ratio
    /// `1 - bounce` overshoots by `exp(-ζπ / √(1 - ζ²))`.
    static func overshoot(bounce: CGFloat) -> CGFloat {
        guard bounce > 0 else { return 0 }
        let damping = 1 - min(bounce, 0.99)
        return exp(-damping * .pi / (1 - damping * damping).squareRoot())
    }

    /// `rect` grown along the edge by `travel`'s overshoot under a
    /// spring of `bounce`, and a point, so the spring's swing past
    /// its target never meets the panel's edge (#2033's room).
    static func room(
        _ rect: CGRect,
        travel: CGFloat,
        bounce: CGFloat,
        horizontal: Bool
    ) -> CGRect {
        let grow = ceil(abs(travel) * overshoot(bounce: bounce)) + 1
        return horizontal
            ? rect.insetBy(dx: -grow, dy: 0)
            : rect.insetBy(dx: 0, dy: -grow)
    }
}
