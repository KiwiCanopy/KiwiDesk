import Foundation

/// The app-wide animation lengths (#3237) reach their readers from
/// here, called by `appWideLiveChanged` alone: the window engine's
/// two cached lengths, and the bars' through `updateBars()`.
extension KiwiCore {
    func animationPaceChanged() {
        syncAnimationEngine()
        updateBars()
    }

    /// The engine caches its two lengths for its hot path; this is
    /// the one writer of them outside its own init.
    func syncAnimationEngine() {
        tiler.animation.durationMS = appWide.animationDurationMS
        tiler.animation.scrollDurationMS = appWide.animationScrollDurationMS
    }
}
