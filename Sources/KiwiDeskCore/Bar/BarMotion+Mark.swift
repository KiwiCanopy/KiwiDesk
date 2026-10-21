import AppKit
import QuartzCore

/// `BarMotion`'s mark half (#761), split from the reveal at the
/// §2.1 target: a hidden shelf's mark grows on hover and gives way
/// to its shelf. The same one home — `BarMotionSeamTests`
/// censuses this file.
extension BarMotion {
    /// How a shelf's reveal plays, as far as its mark keeps time
    /// with it: the user's `reveal_style`, an unfold on a shelf with
    /// no plate spreading its boxes (owner ruling, 2026-10-21) and a
    /// grow there wiping over them; `fade` for a shelf not yet
    /// shown.
    enum RevealKind: Equatable {
        case slide, grow, unfold, spread, fade

        init(_ shelf: KiwiShelf) {
            switch shelf.revealStyle {
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

    /// Where the mark's plate stands in its view: `mark`, grown by
    /// `ShelfIndicatorSpec.hoverGrowth` on every side while
    /// hovered and along the edge by `widen`, a label's room. The
    /// size is content rather than motion, for every mark.
    static func hoverPlate(
        mark: CGRect,
        widen: CGFloat = 0,
        horizontal: Bool = true,
        hovered: Bool
    ) -> CGRect {
        guard hovered else { return mark }
        let growth = ShelfIndicatorSpec.hoverGrowth
        let along = growth + widen / 2
        return horizontal
            ? mark.insetBy(dx: -along, dy: -growth)
            : mark.insetBy(dx: -growth, dy: -along)
    }

    /// Places the mark's `plate` for `hovered` and shows its
    /// `rim` — a view stroking its own bounds, at the hovered
    /// plate's frame so its stroke never stretches — growing and
    /// fading in over `hoverGrow` where `animated`, Reduce Motion
    /// or not (owner ruling, 2026-10-21).
    @MainActor
    static func placeHoverPlate(
        _ plate: NSView,
        rim: NSView,
        mark: CGRect,
        widen: CGFloat = 0,
        horizontal: Bool = true,
        hovered: Bool,
        animated: Bool
    ) {
        let frame = hoverPlate(
            mark: mark,
            widen: widen,
            horizontal: horizontal,
            hovered: hovered
        )
        rim.frame = hoverPlate(
            mark: mark,
            widen: widen,
            horizontal: horizontal,
            hovered: true
        )
        plate.wantsLayer = true
        let write = {
            plate.frame = frame
            plate.layer?.cornerRadius = min(frame.width, frame.height) / 2
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
