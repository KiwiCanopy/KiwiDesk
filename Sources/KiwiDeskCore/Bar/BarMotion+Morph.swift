import AppKit
import QuartzCore

/// `BarMotion`'s peek morph (#2563 ▸ Ruling): the overflow mark's
/// pill grows by its frame into the list and shrinks back into it,
/// on one critically damped spring; under Reduce Motion nothing
/// grows and the pill and the list cross-fade at rest.
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// The open's perceptual length: fixed, never `reveal_duration`,
    /// since a list is a label and not a bar reveal.
    static let morphOpen: TimeInterval = 0.2
    /// The close's: about four fifths of the open.
    static let morphClose: TimeInterval = 0.16
    static let morphKey = "kiwidesk.peekMorph"

    /// Whether the pill grows into the list: never under Reduce
    /// Motion, which cross-fades the two at rest instead.
    static func morphGrows(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// Plays the open (`opening`) or the close of the list `parts`
    /// draw in `panel`, the `anchor`'s panel hiding as it opens, the
    /// stage between `pill` and its own bounds, both in the stage
    /// layer's own coordinates; returns how long until it lands.
    /// Continues from where a morph in flight stands.
    @MainActor
    @discardableResult
    static func playMorph(
        _ parts: BarPeekMorphParts,
        panel: NSWindow,
        anchor: NSWindow?,
        pill: CGRect,
        pillRadius: CGFloat,
        listRadius: CGFloat,
        opening: Bool
    ) -> TimeInterval {
        guard morphGrows(reduceMotion: isReduced) else {
            let to: CGFloat = opening ? 1 : 0
            if opening { panel.alphaValue = 0 }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = peekFade
                panel.animator().alphaValue = to
                anchor?.animator().alphaValue = 1 - to
            }
            return peekFade
        }
        let span = opening ? morphOpen : morphClose
        panel.alphaValue = 1
        if opening { anchor?.alphaValue = 0 }
        let clipLayer = parts.stage
        let current =
            clipLayer.animationKeys()?.contains(morphKey) == true
            ? clipLayer.presentation() : nil
        let full = clipLayer.bounds
        let from = current?.bounds ?? (opening ? pill : full)
        let to = opening ? full : pill
        let clip = morphClip(
            from: (
                from,
                current?.position ?? clipPlace(from, on: clipLayer),
                current?.cornerRadius ?? (opening ? pillRadius : listRadius)
            ),
            to: (
                to,
                clipPlace(to, on: clipLayer),
                opening ? listRadius : pillRadius
            ),
            span: span
        )
        clipLayer.masksToBounds = true
        clipLayer.add(clip, forKey: morphKey)
        let half = span / 2
        parts.rows.add(
            morphFade(
                from: opening ? 0 : 1,
                to: opening ? 1 : 0,
                begin: opening ? half : 0,
                span: half
            ),
            forKey: morphKey
        )
        parts.markInk.add(
            morphFade(
                from: opening ? 1 : 0,
                to: opening ? 0 : 1,
                begin: 0,
                span: span
            ),
            forKey: morphKey
        )
        parts.listInk.add(
            morphFade(
                from: opening ? 0 : 1,
                to: opening ? 1 : 0,
                begin: 0,
                span: span
            ),
            forKey: morphKey
        )
        return opening ? span : settling(span, bounce: 0)
    }

    /// Ends a morph: every part stands at rest, the clip open.
    @MainActor
    static func endMorph(_ parts: BarPeekMorphParts) {
        [parts.stage, parts.rows, parts.markInk, parts.listInk].forEach {
            $0.removeAnimation(forKey: morphKey)
        }
    }

    /// The stage's clip on one critically damped spring: bounds,
    /// position and corner radius, held where it lands — played only
    /// where `morphGrows` let the pill grow.
    private static func morphClip(
        from: ClipStart,
        to: ClipStart,
        span: TimeInterval
    ) -> CAAnimation {
        let group = CAAnimationGroup()
        let parts: [(String, Any, Any)] = [
            ("bounds", from.bounds, to.bounds),
            ("position", from.place, to.place),
            ("cornerRadius", from.radius, to.radius),
        ]
        group.animations = parts.map { path, start, end in
            let spring = CASpringAnimation(
                perceptualDuration: span,
                bounce: 0
            )
            spring.keyPath = path
            spring.fromValue = start
            spring.toValue = end
            spring.duration = spring.settlingDuration
            return spring
        }
        group.duration = settling(span, bounce: 0)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        return group
    }

    /// An opacity fade from `from` to `to` over `span`, `begin`
    /// seconds in, holding its ends either side — the grown morph's
    /// alone.
    private static func morphFade(
        from: Float,
        to: Float,
        begin: TimeInterval,
        span: TimeInterval
    ) -> CAAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = to
        fade.beginTime = CACurrentMediaTime() + begin
        fade.duration = max(span, 0.001)
        fade.fillMode = .both
        fade.isRemovedOnCompletion = false
        return fade
    }
}
