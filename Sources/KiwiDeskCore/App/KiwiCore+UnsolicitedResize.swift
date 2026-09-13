import CoreGraphics

/// A resize nobody asked for — macOS's title-bar zoom, an app
/// re-sizing itself — is corrected NOW rather than at the next
/// unrelated retile (#1358, owner ruling 2026-09-13): a tiled
/// window goes back into its slot, an effective float is fitted
/// clear of the bars. Both are the ordinary retile's own work;
/// this only decides whether one is owed.
extension KiwiCore {
    /// Whether an unsolicited resize left `id` off the frame the
    /// active space gives it: a tiled member off its slot beyond
    /// the retile tolerance, or an effective float the bar fit
    /// would move. False for a window the active space does not
    /// place, and for a native-fullscreen one (#670).
    func unsolicitedResizeLeavesOffFrame(
        _ id: WindowID,
        frame: CGRect
    ) -> Bool {
        guard let space = activeSpace,
            space.windows.contains(id),
            let window = state.windows[id],
            !window.isFullscreen
        else { return false }
        if EffectiveFloat.applies(
            isFloating: window.isFloating,
            mode: space.mode
        ) {
            return floatFrameFittedClearOfBars(id, frame: frame)
                != frame
        }
        guard let slot = tiler.calculatedFrames(state: state)[id]
        else { return false }
        return !TilingEngine.close(frame, to: slot)
    }

    /// The `.windowResized` arm's correction for a resize that is
    /// neither our ask's echo nor a mouse gesture.
    func correctUnsolicitedResize(_ id: WindowID, frame: CGRect) {
        guard unsolicitedResizeLeavesOffFrame(id, frame: frame)
        else { return }
        onLog("unsolicited resize of window \(id.raw) corrected")
        retile(animated: tiler.settings.animations.onWindowResize)
    }
}
