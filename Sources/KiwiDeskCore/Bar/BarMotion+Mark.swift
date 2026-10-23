import AppKit
import QuartzCore

/// `BarMotion`'s mark half (#761), split from the reveal at the
/// §2.1 target: a hidden shelf's mark grows on hover and gives way
/// to its shelf. The same one home — `BarMotionSeamTests`
/// censuses this file.
extension BarMotion {
    /// How a shelf's reveal plays, as far as its mark keeps time
    /// with it: the style the shelf plays (`playedRevealStyle`), an
    /// unfold on a shelf with no plate spreading its boxes (owner
    /// ruling, 2026-10-21); `fade` for a shelf not yet shown.
    enum RevealKind: Equatable {
        case slide, grow, unfold, spread, fade

        init(_ shelf: KiwiShelf) {
            switch shelf.playedRevealStyle {
            case .slide: self = .slide
            case .grow: self = .grow
            case .unfold: self = shelf.drawsPlate ? .unfold : .spread
            case .fade: self = .fade
            }
        }
    }

    /// When the mark's plate and dots fade, and for how long, as
    /// their shelf reveals over them (`showing` false) or retracts
    /// (`showing`): out as the motion starts — under a growing
    /// plate, half its growth — and back over the end of the
    /// retract so it lands with it; a cross-fade with the shelf
    /// where it only fades. Reduce Motion keeps it, as it keeps the
    /// reveal (owner ruling, 2026-10-21).
    static func markFade(
        showing: Bool,
        reveal: RevealKind
    ) -> (delay: TimeInterval, length: TimeInterval) {
        switch reveal {
        case .fade: return (0, revealFade)
        case .slide:
            guard showing else { return (0, revealFade) }
            return (revealSlide - markReturn, markReturn)
        case .grow:
            guard showing else { return (0, ShelfGrow.plateGrow / 2) }
            return (ShelfGrow.retractLength - markReturn, markReturn)
        case .unfold:
            guard showing else { return (0, ShelfUnfold.markFadeOut) }
            return (ShelfUnfold.retractLength - markReturn, markReturn)
        case .spread:
            guard showing else { return (0, ShelfUnfold.markSpreadOut) }
            return (ShelfUnfold.gatherLength - markReturn, markReturn)
        }
    }

    /// How much a motion `natural` seconds long is stretched to
    /// play inside `length` — a retract inside
    /// `AnimationSettings.retractShare` of it.
    static func revealScale(
        _ natural: TimeInterval,
        entering: Bool,
        _ length: TimeInterval
    ) -> Double {
        let target =
            entering ? length : length * AnimationSettings.retractShare
        return natural > 0 && target > 0 ? target / natural : 1
    }

    /// How long `kind`'s motion plays before it is fitted to the
    /// user's length — what `revealMotion` resolves it to.
    static func naturalLength(
        _ kind: RevealKind,
        entering: Bool
    ) -> TimeInterval {
        switch kind {
        case .slide: revealSlide
        case .fade: revealFade
        case .grow: ShelfGrow.length(entering: entering)
        case .unfold: ShelfUnfold.length(entering: entering)
        case .spread: ShelfUnfold.spreadLength(entering: entering)
        }
    }

    /// Fades the mark's `body` in (`showing`) or out as its shelf
    /// retracts or reveals; a fade already playing continues from
    /// where it stands.
    @MainActor
    static func fadeMark(
        _ body: NSView,
        showing: Bool,
        reveal: RevealKind
    ) {
        body.wantsLayer = true
        // A length of 0 swaps the mark at once.
        guard revealLength > 0 else {
            body.layer?.removeAnimation(forKey: revealKey)
            body.alphaValue = showing ? 1 : 0
            return
        }
        let natural = markFade(showing: showing, reveal: reveal)
        // The motion's own scale, so the mark keeps its time.
        let scale = revealScale(
            naturalLength(reveal, entering: !showing),
            entering: !showing,
            revealLength
        )
        let timing = (
            delay: natural.delay * scale,
            length: natural.length * scale
        )
        let from =
            body.layer?.animationKeys()?.contains(revealKey) == true
            ? body.layer?.presentation()?.opacity : nil
        body.alphaValue = showing ? 1 : 0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from ?? (showing ? 0 : 1)
        fade.toValue = showing ? 1 : 0
        fade.duration = timing.length
        fade.beginTime = CACurrentMediaTime() + timing.delay
        fade.fillMode = .backwards
        body.layer?.add(fade, forKey: revealKey)
    }

    /// The hidden mark's hover growth (#761): short, so the plate
    /// reads as answering the pointer. It travels under Reduce
    /// Motion too (owner ruling, 2026-10-21).
    static let hoverGrow: TimeInterval = 0.15

    /// Where the mark's plate stands in its view, y down: `mark`,
    /// grown while hovered by `ShelfIndicatorSpec.hoverGrowth` each
    /// way along `edge` plus half of `widen`, a label's room, and
    /// by twice the growth plus `across`, a side-edge count's room
    /// (#2567), away from the screen side alone — a
    /// plain `NSPanel` is clamped below the menu bar (#436), so a
    /// plate past the screen side moved the mark and the reveal off
    /// the edge. The size is content rather than motion.
    static func hoverPlate(
        mark: CGRect,
        widen: CGFloat = 0,
        across: CGFloat = 0,
        edge: AppBarEdge,
        hovered: Bool
    ) -> CGRect {
        guard hovered else { return mark }
        let growth = ShelfIndicatorSpec.hoverGrowth
        let along = growth + widen / 2
        let deep = growth + across / 2
        let inward = hoverShift(edge, across: across)
        let grown =
            edge.isHorizontal
            ? mark.insetBy(dx: -along, dy: -deep)
            : mark.insetBy(dx: -deep, dy: -along)
        return grown.offsetBy(dx: inward.dx, dy: inward.dy)
    }

    /// How far the hovered plate's middle moves off `edge`'s
    /// screen side, y down: one growth inward, and half of
    /// `across`.
    static func hoverShift(
        _ edge: AppBarEdge,
        across: CGFloat = 0
    ) -> CGVector {
        let growth = ShelfIndicatorSpec.hoverGrowth + across / 2
        switch edge {
        case .top: return CGVector(dx: 0, dy: growth)
        case .bottom: return CGVector(dx: 0, dy: -growth)
        case .left: return CGVector(dx: growth, dy: 0)
        case .right: return CGVector(dx: -growth, dy: 0)
        }
    }

    /// Places the mark's `plate` for `hovered` and shows its
    /// `rim` — a view stroking its own bounds, at the hovered
    /// plate's frame so its stroke never stretches — growing and
    /// fading in over `hoverGrow` where `animated`, Reduce Motion
    /// or not (owner ruling, 2026-10-21). `content`, resting at
    /// `contentRest`, moves with the plate's middle. `placePlate`
    /// writes a plate that is no plain view — a glass box's host,
    /// which travels with its pair (#2567) — inside the same motion.
    @MainActor
    static func placeHoverPlate(
        _ plate: NSView,
        rim: NSView,
        content: NSView,
        contentRest: CGRect,
        mark: CGRect,
        widen: CGFloat = 0,
        across: CGFloat = 0,
        edge: AppBarEdge,
        hovered: Bool,
        animated: Bool,
        placePlate: ((CGRect) -> Void)? = nil
    ) {
        let frame = hoverPlate(
            mark: mark,
            widen: widen,
            across: across,
            edge: edge,
            hovered: hovered
        )
        rim.frame = hoverPlate(
            mark: mark,
            widen: widen,
            across: across,
            edge: edge,
            hovered: true
        )
        let shift = hovered ? hoverShift(edge, across: across) : .zero
        let contentFrame = contentRest.offsetBy(dx: shift.dx, dy: shift.dy)
        plate.wantsLayer = true
        let write = {
            if let placePlate {
                placePlate(frame)
            } else {
                plate.frame = frame
                plate.layer?.cornerRadius = min(frame.width, frame.height) / 2
            }
            content.frame = contentFrame
            rim.alphaValue = hovered ? 1 : 0
        }
        guard animated, plate.frame != frame else {
            write()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = hoverGrow
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            context.allowsImplicitAnimation = true
            write()
        }
    }
}
