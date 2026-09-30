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

    /// Removes `views` once an item slide lands — a timer of the
    /// slide's length, as `playWalk` does — and at once under
    /// Reduce Motion, which plays no slide.
    @MainActor
    static func removeAfterSlide(_ views: [NSView]) {
        let span = duration(reduceMotion: isReduced)
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
