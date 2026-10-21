import AppKit
import QuartzCore

/// `BarMotion`'s mark half (#761), split from the reveal at the
/// §2.1 target: a hidden shelf's mark grows on hover and gives way
/// to its shelf. The same one home — `BarMotionSeamTests`
/// censuses this file.
extension BarMotion {
    /// How a shelf's reveal plays, as far as its mark keeps time
    /// with it: the user's `reveal_style`, a grow on a shelf with no
    /// plate cross-fading (#2497).
    enum RevealKind: Equatable {
        case slide, grow, fade

        init(_ shelf: KiwiShelf) {
            switch shelf.revealStyle {
            case .slide: self = .slide
            case .grow: self = shelf.drawsPlate ? .grow : .fade
            }
        }
    }

    /// When the mark's plate and dots fade, and for how long, as
    /// their shelf reveals over them (`showing` false) or retracts
    /// (`showing`): out as the motion starts — under a growing
    /// plate, half its growth — and back over the end of the
    /// retract so it lands with it; a cross-fade with the shelf
    /// where it only fades.
    static func markFade(
        showing: Bool,
        reveal: RevealKind,
        reduceMotion: Bool
    ) -> (delay: TimeInterval, length: TimeInterval) {
        guard !reduceMotion else { return (0, revealFade) }
        switch reveal {
        case .fade: return (0, revealFade)
        case .slide:
            guard showing else { return (0, revealFade) }
            return (revealSlide - markReturn, markReturn)
        case .grow:
            guard showing else { return (0, ShelfGrow.plateGrow / 2) }
            return (ShelfGrow.retractLength - markReturn, markReturn)
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
        let timing = markFade(
            showing: showing,
            reveal: reveal,
            reduceMotion: isReduced
        )
        body.wantsLayer = true
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
    /// reads as answering the pointer.
    static let hoverGrow: TimeInterval = 0.15

    /// How long the hover growth travels: none under Reduce Motion,
    /// where the plate lands at its hovered size at once.
    static func hoverGrowDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : hoverGrow
    }

    /// Where the mark's plate stands in its view: `mark`, grown by
    /// `ShelfIndicatorSpec.hoverGrowth` on every side while
    /// hovered and along the edge by `widen`, a label's room. The
    /// size is content rather than motion, so Reduce Motion keeps
    /// it and drops only the growth's animation, for every mark.
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
    /// fading in over `hoverGrow` where `animated`; under Reduce
    /// Motion both land at once.
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
        let duration = hoverGrowDuration(reduceMotion: isReduced)
        guard animated, duration > 0, plate.frame != frame else {
            write()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            context.allowsImplicitAnimation = true
            write()
        }
    }
}
