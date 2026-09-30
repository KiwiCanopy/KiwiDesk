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

    /// Runs `body` once a group glide lands — a timer of the plate
    /// glide's length, as `playWalk` does, and the next turn under
    /// Reduce Motion, which plays no glide. Never inline: it is
    /// scheduled from inside a render, which `body` may re-run.
    @MainActor
    static func afterGroupGlide(
        _ body: @escaping @MainActor () -> Void
    ) {
        let span = plateGlideDuration(reduceMotion: isReduced)
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            body()
        }
    }
}
