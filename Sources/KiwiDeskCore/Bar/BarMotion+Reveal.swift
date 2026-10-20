import AppKit
import QuartzCore

/// `BarMotion`'s reveal half (#761, #2497): a hiding shelf slides
/// in from its screen side whole, its content already laid out,
/// and back out the same way; it cross-fades in place under Reduce
/// Motion. The same one home — `BarMotionSeamTests` censuses this
/// file.
extension BarMotion {
    /// How a reveal or a retract plays.
    enum RevealMotion: Equatable {
        /// The content travels from `offset` (its own coordinates)
        /// to its rest, or back, over `length`.
        case slide(offset: CGVector, length: TimeInterval)
        /// It cross-fades in place: Reduce Motion drops the travel.
        case fade(TimeInterval)
    }

    /// The slide's length and curve (owner ruling, #2497): the
    /// prototype's numbers, fixed like the mark's own timings.
    static let revealSlide: TimeInterval = 0.28
    static let revealCurve: (Float, Float, Float, Float) = (0.3, 0.7, 0.2, 1)
    /// The cross-fade's length, as the peek's.
    static let revealFade: TimeInterval = 0.1
    /// How long the mark fades back at the end of a retract,
    /// landing with it.
    static let markReturn: TimeInterval = 0.06
    /// How long a reveal stands at its start after the commit that
    /// orders the panel in: a freshly ordered window reaches the
    /// screen a frame or two after that commit, and a clock
    /// started there loses the travel those frames carry.
    static let revealLead: TimeInterval = 1.0 / 30

    /// Where a shelf on `edge` starts its slide, in its flipped
    /// content coordinates: past its screen side by its `depth`
    /// and the `gap` to the usable area's edge, so it starts
    /// wholly clipped and comes out from under the menu bar.
    static func revealOffset(
        edge: AppBarEdge,
        depth: CGFloat,
        gap: CGFloat
    ) -> CGVector {
        let travel = depth + max(gap, 0)
        switch edge {
        case .top: return CGVector(dx: 0, dy: -travel)
        case .bottom: return CGVector(dx: 0, dy: travel)
        case .left: return CGVector(dx: -travel, dy: 0)
        case .right: return CGVector(dx: travel, dy: 0)
        }
    }

    /// The motion for a reveal or a retract travelling `offset`.
    static func revealMotion(
        reduceMotion: Bool,
        offset: CGVector
    ) -> RevealMotion {
        guard !reduceMotion, offset != .zero else {
            return .fade(revealFade)
        }
        return .slide(offset: offset, length: revealSlide)
    }

    /// The reveal's animation key, on the content.
    static let revealKey = "kiwi.reveal"

    /// The slide `view` is in, as a position shift in its
    /// superlayer, nil where none plays. Read it before the view's
    /// frame moves in the same pass: the presentation shows the
    /// last commit, the model the new frame.
    @MainActor
    static func revealShift(of view: NSView) -> CGPoint? {
        guard let layer = view.layer,
            layer.animationKeys()?.contains(revealKey) == true,
            let shown = layer.presentation()
        else { return nil }
        return CGPoint(
            x: shown.position.x - layer.position.x,
            y: shown.position.y - layer.position.y
        )
    }

    /// Plays a reveal (`entering`) or a retract on `view`, the
    /// panel's content, and returns its length; the caller lands
    /// it through its own `afterReveal` seam. A `held` start
    /// stands still until a later call replaces it — the pass that
    /// orders the panel in holds it — and a `lead` start waits
    /// `revealLead` first. The slide is ADDITIVE on the layer's
    /// position, so a resize of the panel's room under it moves
    /// nothing; a slide already playing continues from `from`
    /// (`revealShift`), a fade from where it stands.
    @MainActor
    @discardableResult
    static func playReveal(
        _ view: NSView,
        offset: CGVector,
        entering: Bool,
        from: CGPoint? = nil,
        held: Bool = false,
        lead: Bool = false
    ) -> TimeInterval {
        view.wantsLayer = true
        guard let layer = view.layer else { return 0 }
        let motion = revealMotion(reduceMotion: isReduced, offset: offset)
        let current =
            layer.animationKeys()?.contains(revealKey) == true
            ? layer.presentation() : nil
        let start = held ? 0 : CACurrentMediaTime() + (lead ? revealLead : 0)
        let timed = { (animation: CAAnimation) in
            animation.fillMode = .both
            animation.isRemovedOnCompletion = false
            if held {
                animation.speed = 0
            } else {
                animation.beginTime = start
            }
        }
        let tail = lead ? revealLead : 0
        switch motion {
        case .fade(let span):
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = current?.opacity ?? (entering ? 0 : 1)
            fade.toValue = entering ? 1 : 0
            fade.duration = span
            timed(fade)
            layer.add(fade, forKey: revealKey)
            return held ? 0 : span + tail
        case .slide(let offset, let span):
            // The offset in the superlayer's coordinates, whichever
            // way each layer is flipped.
            let rest = layer.convert(layer.bounds, to: layer.superlayer)
            let away = layer.convert(
                layer.bounds.offsetBy(dx: offset.dx, dy: offset.dy),
                to: layer.superlayer
            )
            let shift = CGPoint(
                x: away.minX - rest.minX,
                y: away.minY - rest.minY
            )
            let slide = CABasicAnimation(keyPath: "position")
            slide.isAdditive = true
            slide.fromValue = NSValue(
                point: from ?? (entering ? shift : .zero)
            )
            slide.toValue = NSValue(point: entering ? .zero : shift)
            slide.duration = span
            let (a, b, c, d) = revealCurve
            // A retract plays the reveal's curve backwards.
            slide.timingFunction =
                entering
                ? CAMediaTimingFunction(controlPoints: a, b, c, d)
                : CAMediaTimingFunction(
                    controlPoints: 1 - c,
                    1 - d,
                    1 - a,
                    1 - b
                )
            timed(slide)
            layer.add(slide, forKey: revealKey)
            return held ? 0 : span + tail
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

    /// Ends a reveal's motion on `view`: it stands where it rests,
    /// opaque.
    @MainActor
    static func endReveal(_ view: NSView) {
        view.layer?.removeAnimation(forKey: revealKey)
    }
}
