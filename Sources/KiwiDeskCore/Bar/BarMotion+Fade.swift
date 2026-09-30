import AppKit

/// `BarMotion`'s fade half (#1831), split at the §2.1 ceiling: the
/// App Bar group's members sliding into its item and out of it.
/// The same one home — `BarMotionSeamTests` censuses both files.
extension BarMotion {
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

    /// A group's members sliding together or apart (#1831): longer
    /// than an item slide, which read as a snap for this travel
    /// (owner, 2026-09-30), so a render that folds or releases a
    /// member takes it for its whole pass and the row keeps step.
    static let groupGlide: TimeInterval = 0.35

    /// The group glide's length, nothing under Reduce Motion.
    static func groupGlideDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : groupGlide
    }

    /// Runs `body` in the group glide's animation group.
    @MainActor
    static func runGroupLayout(_ body: () -> Void) {
        let reduceMotion = isReduced
        NSAnimationContext.runAnimationGroup { context in
            context.duration = groupGlideDuration(
                reduceMotion: reduceMotion
            )
            context.timingFunction = CAMediaTimingFunction(
                name: .easeInEaseOut
            )
            body()
        }
    }

    /// Removes `views` once the group glide lands — a timer of its
    /// length, as `playWalk` does — and at once under Reduce
    /// Motion, which plays no glide.
    @MainActor
    static func removeAfterGroupGlide(_ views: [NSView]) {
        let span = groupGlideDuration(reduceMotion: isReduced)
        guard span > 0 else {
            views.forEach { $0.removeFromSuperview() }
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(span))
            views.forEach { $0.removeFromSuperview() }
        }
    }
}
