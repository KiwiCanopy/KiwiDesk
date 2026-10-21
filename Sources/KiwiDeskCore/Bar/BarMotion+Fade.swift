import AppKit

/// `BarMotion`'s fade half (#1831), split at the §2.1 ceiling: the
/// App Bar group's members sliding into its item and out of it.
/// The same one home — `BarMotionSeamTests` censuses both files.
extension BarMotion {
    /// The shelf glide's length (#1838), the user's
    /// `animations.expand_duration` — nothing while `on_expand` is
    /// off — kept current by `KiwiCore.updateBars()`.
    @MainActor static var shelfGlide: TimeInterval =
        AnimationSettings().expandSeconds

    /// The plate glide's live length, the user's `shelfGlide` —
    /// what a stand reads to know whether anything will travel at
    /// all.
    @MainActor
    static var shelfGlideLength: TimeInterval {
        shelfGlide
    }

    /// Runs `body`'s writes with no implicit motion and COMMITS
    /// them: an animation started after it begins from what `body`
    /// stood rather than from the last committed presentation,
    /// which is where the animator reads its start (#1838).
    @MainActor
    static func standCommitted(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
        CATransaction.flush()
    }

    /// Fades `view` to `alpha` inside the running layout group,
    /// landing at once where `fades` refuses.
    @MainActor
    static func setAlpha(
        _ view: NSView,
        to alpha: CGFloat,
        animated: Bool
    ) {
        if fades(animated, reduceMotion: isReduced) {
            view.animator().alphaValue = alpha
        } else {
            view.alphaValue = alpha
        }
    }

    /// Whether an alpha write may fade.
    static func fades(_ animated: Bool, reduceMotion: Bool) -> Bool {
        animated && !reduceMotion
    }

    /// The hover peek's fade (#1946): short, so the label reads as
    /// appearing rather than arriving; never a slide.
    static let peekFade: TimeInterval = 0.1

    /// The peek fade's length: none where it is not animated or
    /// under Reduce Motion, which snaps.
    static func peekFadeDuration(
        _ animated: Bool,
        reduceMotion: Bool
    ) -> TimeInterval {
        fades(animated, reduceMotion: reduceMotion) ? peekFade : 0
    }

    /// Fades the peek's `panel` to `alpha`; `landed` runs once it
    /// is there — inline where nothing fades, else on a timer of
    /// the fade's length, as `playWalk` lands.
    @MainActor
    static func fadePeek(
        _ panel: NSWindow,
        to alpha: CGFloat,
        animated: Bool,
        landed: @escaping @MainActor () -> Void = {}
    ) {
        let span = peekFadeDuration(animated, reduceMotion: isReduced)
        guard span > 0 else {
            // Replaces a fade still running, which a bare write
            // would leave to finish over it.
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                panel.animator().alphaValue = alpha
            }
            panel.alphaValue = alpha
            landed()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = span
            panel.animator().alphaValue = alpha
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(span))
            landed()
        }
    }

    /// The share of the plate glide a dissolve's OUT-fade takes
    /// (#1838): the old row goes early while the new keeps fading
    /// in over the whole glide, so a longer old row is not seen
    /// beneath the new at half strength midway. Under half, or the
    /// two rows meet at equal strength; well over a third, or the
    /// old row reads as cut. Owner-tuned on device, 2026-10-01.
    static let dissolveOutShare = 0.4

    /// Runs `body` in a dissolve's out-fade group, nested in the
    /// plate glide: `dissolveOutShare` of its length, the same
    /// curve.
    @MainActor
    static func runDissolveOut(_ body: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = dissolveOutDuration(seconds: shelfGlide)
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.2,
                0.9,
                0.3,
                1
            )
            body()
        }
    }

    /// The out-fade's length: `dissolveOutShare` of the plate
    /// glide's.
    static func dissolveOutDuration(seconds: TimeInterval) -> TimeInterval {
        seconds * dissolveOutShare
    }

    /// Runs `body` once a group glide lands — a timer of the plate
    /// glide's length, as `playWalk` does, and the next turn where
    /// the expand is off. Never inline: it is
    /// scheduled from inside a render, which `body` may re-run.
    @MainActor
    static func afterGroupGlide(
        _ body: @escaping @MainActor () -> Void
    ) {
        let span = shelfGlide
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            body()
        }
    }

    /// A layer `opacity` fade from `from` to `to` across
    /// `duration`, starting at render-server time `begin` — the
    /// focused ring's arrival reveal (#1959). Forwards only: a
    /// later fade on the key must not be overridden from the
    /// start.
    static func opacityFade(
        from: Float,
        to: Float,
        begin: CFTimeInterval,
        duration: CFTimeInterval,
        reduceMotion: Bool,
        timing: CAMediaTimingFunction = CAMediaTimingFunction(
            name: .easeOut
        )
    ) -> CAAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = reduceMotion ? to : from
        fade.toValue = to
        fade.beginTime = begin
        fade.duration = max(duration, 0.001)
        fade.timingFunction = timing
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        return fade
    }
}
