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
    /// hovered — never under Reduce Motion, which keeps the rim
    /// alone.
    static func hoverPlate(
        mark: CGRect,
        hovered: Bool,
        reduceMotion: Bool
    ) -> CGRect {
        guard hovered, !reduceMotion else { return mark }
        let growth = ShelfIndicatorSpec.hoverGrowth
        return mark.insetBy(dx: -growth, dy: -growth)
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
        hovered: Bool,
        animated: Bool
    ) {
        let frame = hoverPlate(
            mark: mark,
            hovered: hovered,
            reduceMotion: isReduced
        )
        rim.frame = hoverPlate(
            mark: mark,
            hovered: true,
            reduceMotion: isReduced
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
