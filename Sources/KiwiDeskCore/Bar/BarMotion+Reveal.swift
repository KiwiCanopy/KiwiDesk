import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761): a hiding shelf grows out of
/// its hidden mark and back into it, and fades in place under
/// Reduce Motion; the mark's plate grows on hover.
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// How a reveal or a retract travels.
    enum RevealMotion: Equatable {
        /// The shelf grows out of its hidden mark's plate — the
        /// mark its upper end — to the whole panel, or back into
        /// it: a clip from `from` to `to`, in the content layer's
        /// own coordinates, its corners rounding off the mark's.
        case grow(from: CGRect, to: CGRect, radius: CGFloat, TimeInterval)
        /// It fades in place: Reduce Motion drops the travel,
        /// never the reveal.
        case fade(TimeInterval)
    }

    /// The grow's length (ui-designer, #761, lengthened on device
    /// feedback): one step past the plate glide, so a whole shelf
    /// reads as arriving rather than jumping.
    static let revealSlide: TimeInterval = 0.25
    /// The Reduce Motion fade's, as the peek's.
    static let revealFade: TimeInterval = 0.1
    /// How long a grow stands at its start after the commit that
    /// orders the panel in: a freshly ordered window reaches the
    /// screen a frame or two after that commit, and a clock
    /// started there loses the travel those frames carry.
    static let revealLead: TimeInterval = 1.0 / 30

    /// The motion for a shelf whose content spans `bounds`, growing
    /// out of its mark at `origin` — taken at its hovered size,
    /// the plate a reveal out of the hover leaves.
    static func revealMotion(
        reduceMotion: Bool,
        origin: CGRect,
        bounds: CGRect
    ) -> RevealMotion {
        guard !reduceMotion else { return .fade(revealFade) }
        let grown = origin.insetBy(
            dx: -ShelfIndicatorSpec.hoverGrowth,
            dy: -ShelfIndicatorSpec.hoverGrowth
        )
        return .grow(
            from: grown,
            to: bounds,
            radius: min(grown.width, grown.height) / 2,
            revealSlide
        )
    }

    /// Plays a reveal (`entering`) or a retract on `view`, the
    /// panel's content, out of or into its mark at `origin`, and
    /// returns its length; the caller lands it through its own
    /// `afterReveal` seam. A `held` start stands still until a
    /// later call replaces it — the pass that orders the panel in
    /// holds it — and a `lead` start waits `revealLead` first. A
    /// grow clips the content's own layer, which
    /// already clips its bounds, so no mask is rendered off
    /// screen per frame; one already playing continues from where
    /// it stands.
    @MainActor
    @discardableResult
    static func playReveal(
        _ view: NSView,
        origin: CGRect,
        entering: Bool,
        held: Bool = false,
        lead: Bool = false
    ) -> TimeInterval {
        view.wantsLayer = true
        guard let layer = view.layer else { return 0 }
        let motion = revealMotion(
            reduceMotion: isReduced,
            origin: origin,
            bounds: view.bounds
        )
        // A motion already playing is taken over from where it
        // stands.
        let current =
            layer.animationKeys()?.contains("kiwi.reveal") == true
            ? layer.presentation() : nil
        let animation: CAAnimation
        let duration: TimeInterval
        switch motion {
        case .grow(let mark, let whole, let radius, let span):
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
            let start = entering ? mark : whole
            let end = entering ? whole : mark
            let bounds = CABasicAnimation(keyPath: "bounds")
            bounds.fromValue = current?.bounds ?? start
            bounds.toValue = end
            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = current?.position ?? place(start)
            position.toValue = place(end)
            let corner = CABasicAnimation(keyPath: "cornerRadius")
            corner.fromValue =
                current?.cornerRadius ?? (entering ? radius : 0)
            corner.toValue = entering ? 0 : radius
            let group = CAAnimationGroup()
            group.animations = [bounds, position, corner]
            group.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.25,
                0.1,
                0.25,
                1
            )
            animation = group
            duration = span
        case .fade(let span):
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue =
                current?.opacity ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            animation = fade
            duration = span
        }
        animation.duration = duration
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        if held {
            animation.speed = 0
        } else if lead {
            animation.beginTime = CACurrentMediaTime() + revealLead
        }
        layer.add(animation, forKey: "kiwi.reveal")
        if held { return 0 }
        return duration + (lead ? revealLead : 0)
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

    /// Ends a reveal's motion on `view`: the content stands where
    /// it rests, unclipped.
    @MainActor
    static func endReveal(_ view: NSView) {
        view.layer?.removeAnimation(forKey: "kiwi.reveal")
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

    /// Places the mark's `plate` for `hovered`, its rim `rim` wide,
    /// growing into it over `hoverGrow` where `animated` and
    /// landing at once under Reduce Motion.
    @MainActor
    static func placeHoverPlate(
        _ plate: NSView,
        mark: CGRect,
        hovered: Bool,
        rim: CGFloat,
        animated: Bool
    ) {
        let frame = hoverPlate(
            mark: mark,
            hovered: hovered,
            reduceMotion: isReduced
        )
        let radius = min(frame.width, frame.height) / 2
        plate.wantsLayer = true
        let write = {
            plate.frame = frame
            plate.layer?.cornerRadius = radius
            plate.layer?.borderWidth = rim
        }
        // Under Reduce Motion the plate keeps its frame, so only
        // the rim changes, at once.
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
