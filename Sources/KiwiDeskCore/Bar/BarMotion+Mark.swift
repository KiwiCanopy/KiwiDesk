import AppKit
import QuartzCore

/// `BarMotion`'s mark half (#761), split from the reveal at the
/// §2.1 target: a hidden shelf's mark grows on hover and gives way
/// to its shelf. The same one home — `BarMotionSeamTests`
/// censuses this file.
extension BarMotion {
    /// When the mark's plate and dots fade, and for how long, as
    /// their shelf reveals over them (`showing` false) or retracts
    /// (`showing`): out under a growing plate; back over the end of
    /// a morph's retract so it lands with it; a cross-fade with
    /// the shelf otherwise.
    static func markFade(
        showing: Bool,
        morphs: Bool,
        reduceMotion: Bool
    ) -> (delay: TimeInterval, length: TimeInterval) {
        guard morphs, !reduceMotion else { return (0, revealFade) }
        guard showing else { return (0, plateGrow / 2) }
        return (itemsFadeOut + plateShrink - markReturn, markReturn)
    }

    /// Fades the mark's `body` in (`showing`) or out as its shelf
    /// retracts or reveals; a fade already playing continues from
    /// where it stands.
    @MainActor
    static func fadeMark(_ body: NSView, showing: Bool, morphs: Bool) {
        let timing = markFade(
            showing: showing,
            morphs: morphs,
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

    /// Where the mark's plate stands in its view: `mark`, grown by
    /// `ShelfIndicatorSpec.hoverGrowth` on every side while
    /// hovered and along the edge by `widen`, a label's room —
    /// never under Reduce Motion, which keeps the rim alone, save
    /// for a label, which is content rather than motion and takes
    /// its room at once.
    static func hoverPlate(
        mark: CGRect,
        widen: CGFloat = 0,
        horizontal: Bool = true,
        hovered: Bool,
        reduceMotion: Bool
    ) -> CGRect {
        guard hovered, !reduceMotion || widen > 0 else { return mark }
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
    /// Motion the plate keeps its frame and the rim appears alone.
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
            hovered: hovered,
            reduceMotion: isReduced
        )
        rim.frame = hoverPlate(
            mark: mark,
            widen: widen,
            horizontal: horizontal,
            hovered: true,
            reduceMotion: isReduced
        )
        plate.wantsLayer = true
        let write = {
            plate.frame = frame
            plate.layer?.cornerRadius = min(frame.width, frame.height) / 2
            rim.alphaValue = hovered ? 1 : 0
        }
        guard animated, !isReduced, plate.frame != frame else {
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
