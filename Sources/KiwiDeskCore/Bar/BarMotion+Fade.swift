import AppKit

/// `BarMotion`'s fade half (#1831), split at the §2.1 ceiling: the
/// App Bar group's members sliding into its item and out of it.
/// The same one home — `BarMotionSeamTests` censuses both files.
extension BarMotion {
    /// The shelf glide's length (#1838), the user's
    /// `animations.shelf_duration` — nothing while `on_shelf` is
    /// off — kept current by `KiwiCore.updateBars()`.
    @MainActor static var shelfGlide: TimeInterval =
        AnimationSettings().shelfGlideSeconds

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

    /// The share of the plate glide a dissolve's OUT-fade takes
    /// (#1838): the old row goes early while the new keeps fading
    /// in over the whole glide, so a longer old row is not seen
    /// beneath the new at half strength midway. Under half, or the
    /// two rows meet at equal strength; well over a third, or the
    /// old row reads as cut. Owner-tuned on device, 2026-10-01.
    static let dissolveOutShare = 0.4

    /// Runs `body` in a dissolve's out-fade group, nested in the
    /// plate glide: `dissolveOutShare` of its length, the same
    /// curve, zero under Reduce Motion.
    @MainActor
    static func runDissolveOut(_ body: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = dissolveOutDuration(
                reduceMotion: isReduced,
                seconds: shelfGlide
            )
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
    /// glide's, zero under Reduce Motion.
    static func dissolveOutDuration(
        reduceMotion: Bool,
        seconds: TimeInterval
    ) -> TimeInterval {
        plateGlideDuration(reduceMotion: reduceMotion, seconds: seconds)
            * dissolveOutShare
    }

    /// Runs `body` once a group glide lands — a timer of the plate
    /// glide's length, as `playWalk` does, and the next turn under
    /// Reduce Motion, which plays no glide. Never inline: it is
    /// scheduled from inside a render, which `body` may re-run.
    @MainActor
    static func afterGroupGlide(
        _ body: @escaping @MainActor () -> Void
    ) {
        let span = plateGlideDuration(
            reduceMotion: isReduced,
            seconds: shelfGlide
        )
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            body()
        }
    }
}
