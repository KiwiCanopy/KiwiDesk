import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761): a hiding shelf's plate grows
/// out of its hidden mark and back into it, its items fading on
/// it, and it cross-fades in place under Reduce Motion or where it
/// draws no plate. The same one home — `BarMotionSeamTests`
/// censuses this file.
extension BarMotion {
    /// How a reveal or a retract plays.
    enum RevealMotion: Equatable {
        /// The plate grows out of the hidden mark — the mark its
        /// upper end — and the items fade up on it, or fade out
        /// before it shrinks back into the mark.
        case morph(Morph)
        /// It cross-fades in place: Reduce Motion drops the
        /// travel, and a Boxed shelf has no plate to grow.
        case fade(TimeInterval)
    }

    /// A morph's two channels, timed from the motion's start: a
    /// clip from `mark` to `plate` (the content layer's own
    /// coordinates) and the items' fade.
    struct Morph: Equatable {
        let entering: Bool
        let mark: CGRect
        let plate: CGRect
        let markRadius: CGFloat
        let plateRadius: CGFloat
        let plateStart: TimeInterval
        let plateLength: TimeInterval
        let itemsStart: TimeInterval
        let itemsLength: TimeInterval
        /// Until both channels have landed.
        let length: TimeInterval
    }

    /// The morph's timings (ruling on #761): the plate grows over
    /// `plateGrow` while the items fade up over `itemsFadeIn` from
    /// `itemsDelay`; a retract fades the items over `itemsFadeOut`
    /// and then shrinks the plate over `plateShrink`.
    static let plateGrow: TimeInterval = 0.24
    static let itemsDelay: TimeInterval = 0.08
    static let itemsFadeIn: TimeInterval = 0.16
    static let itemsFadeOut: TimeInterval = 0.08
    static let plateShrink: TimeInterval = 0.18
    /// The cross-fade's length, as the peek's.
    static let revealFade: TimeInterval = 0.1
    /// How long the mark fades back at the end of a morph's
    /// retract, landing with it.
    static let markReturn: TimeInterval = 0.06
    /// How long a reveal stands at its start after the commit that
    /// orders the panel in: a freshly ordered window reaches the
    /// screen a frame or two after that commit, and a clock
    /// started there loses the travel those frames carry.
    static let revealLead: TimeInterval = 1.0 / 30

    /// The motion for a reveal (`entering`) or a retract out of or
    /// into the mark at `origin` — taken at its hovered size, the
    /// plate a reveal out of the hover leaves — onto `plate`, the
    /// plate's frame, nil where the shelf draws none.
    static func revealMotion(
        reduceMotion: Bool,
        entering: Bool,
        origin: CGRect,
        plate: CGRect?,
        plateRadius: CGFloat
    ) -> RevealMotion {
        guard !reduceMotion, let plate else { return .fade(revealFade) }
        let mark = origin.insetBy(
            dx: -ShelfIndicatorSpec.hoverGrowth,
            dy: -ShelfIndicatorSpec.hoverGrowth
        )
        let plateStart = entering ? 0 : itemsFadeOut
        let plateLength = entering ? plateGrow : plateShrink
        let itemsStart = entering ? itemsDelay : 0
        let itemsLength = entering ? itemsFadeIn : itemsFadeOut
        return .morph(
            Morph(
                entering: entering,
                mark: mark,
                plate: plate,
                markRadius: min(mark.width, mark.height) / 2,
                plateRadius: plateRadius,
                plateStart: plateStart,
                plateLength: plateLength,
                itemsStart: itemsStart,
                itemsLength: itemsLength,
                length: max(
                    plateStart + plateLength,
                    itemsStart + itemsLength
                )
            )
        )
    }

    /// The reveal's animation key, on the content and the items.
    static let revealKey = "kiwi.reveal"

    /// Plays a reveal (`entering`) or a retract on `view`, the
    /// panel's content, with `items` the section strip, and
    /// returns its length; the caller lands it through its own
    /// `afterReveal` seam. A `held` start stands still until a
    /// later call replaces it — the pass that orders the panel in
    /// holds it — and a `lead` start waits `revealLead` first. The
    /// plate grows as a clip of the content's own layer, so no
    /// glass moves or fades; the items fade as one ancestor. A
    /// motion already playing continues from where it stands.
    @MainActor
    @discardableResult
    static func playReveal(
        _ view: NSView,
        items: NSView,
        origin: CGRect,
        plate: (frame: CGRect, radius: CGFloat)?,
        entering: Bool,
        held: Bool = false,
        lead: Bool = false
    ) -> TimeInterval {
        view.wantsLayer = true
        items.wantsLayer = true
        guard let layer = view.layer, let strip = items.layer else {
            return 0
        }
        let motion = revealMotion(
            reduceMotion: isReduced,
            entering: entering,
            origin: origin,
            plate: plate?.frame,
            plateRadius: plate?.radius ?? 0
        )
        let playing = { (layer: CALayer) -> CALayer? in
            layer.animationKeys()?.contains(revealKey) == true
                ? layer.presentation() : nil
        }
        let current = playing(layer)
        let shown = playing(strip)?.opacity
        let start = held ? 0 : CACurrentMediaTime() + (lead ? revealLead : 0)
        let timed = { (animation: CAAnimation, at: TimeInterval) in
            animation.fillMode = .both
            animation.isRemovedOnCompletion = false
            if held {
                animation.speed = 0
            } else {
                animation.beginTime = start + at
            }
        }
        switch motion {
        case .fade(let span):
            strip.removeAnimation(forKey: revealKey)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = current?.opacity ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            fade.duration = span
            timed(fade, 0)
            layer.add(fade, forKey: revealKey)
            return held ? 0 : span + (lead ? revealLead : 0)
        case .morph(let morph):
            // The clip is the layer's own bounds: its origin keeps
            // the content where it rests while its frame — the
            // position — moves to the clip's place.
            let place = { (rect: CGRect) -> CGPoint in
                let frame = layer.convert(rect, to: layer.superlayer)
                let anchor = layer.anchorPoint
                return CGPoint(
                    x: frame.minX + anchor.x * frame.width,
                    y: frame.minY + anchor.y * frame.height
                )
            }
            let from = entering ? morph.mark : morph.plate
            let to = entering ? morph.plate : morph.mark
            let bounds = CABasicAnimation(keyPath: "bounds")
            bounds.fromValue = current?.bounds ?? from
            bounds.toValue = to
            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = current?.position ?? place(from)
            position.toValue = place(to)
            let corner = CABasicAnimation(keyPath: "cornerRadius")
            corner.fromValue =
                current?.cornerRadius
                ?? (entering ? morph.markRadius : morph.plateRadius)
            corner.toValue = entering ? morph.plateRadius : morph.markRadius
            let clip = CAAnimationGroup()
            clip.animations = [bounds, position, corner]
            clip.duration = morph.plateLength
            clip.timingFunction =
                entering
                ? CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
                : CAMediaTimingFunction(controlPoints: 0.4, 0, 1, 1)
            timed(clip, morph.plateStart)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = shown ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            fade.duration = morph.itemsLength
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            timed(fade, morph.itemsStart)
            layer.add(clip, forKey: revealKey)
            strip.add(fade, forKey: revealKey)
            return held ? 0 : morph.length + (lead ? revealLead : 0)
        }
    }

    /// Runs `body` in the main run loop's next pass once this one
    /// has committed — after AppKit has sent the order-in made in
    /// it (`MainRunLoopPass`, #1956) — the overlay's
    /// `afterCommit` default; a test runs it inline.
    @MainActor
    static func afterCommit(_ body: @escaping @MainActor () -> Void) {
        let main = CFRunLoopGetMain()
        // Ordered last among the before-waiting observers, as
        // `MainRunLoopPass` counts, so the commit has run.
        let observer = CFRunLoopObserverCreateWithHandler(
            nil,
            CFRunLoopActivity.beforeWaiting.rawValue,
            false,
            CFIndex.max
        ) { _, _ in
            CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) {
                MainActor.assumeIsolated { body() }
            }
            CFRunLoopWakeUp(main)
        }
        CFRunLoopAddObserver(main, observer, .commonModes)
    }

    /// Runs `body` once a reveal of `span` seconds has landed — the
    /// overlay's `afterReveal` default; a test hands a queue.
    @MainActor
    static func afterReveal(
        _ span: TimeInterval,
        _ body: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            body()
        }
    }

    /// Ends a reveal's motion on `view` and its `items`: both
    /// stand where they rest, unclipped and opaque.
    @MainActor
    static func endReveal(_ view: NSView, items: NSView) {
        view.layer?.removeAnimation(forKey: revealKey)
        items.layer?.removeAnimation(forKey: revealKey)
    }
}
