import Foundation

/// The single settings↔engine boundary for animation durations
/// (issue #51). The engine caches `durationMS`/`scrollDurationMS`
/// for the hot animation path, so those values are mirrored from
/// the persisted `TilingSettings`. Routing every write through
/// these helpers keeps the two copies from diverging — the drift
/// hazard flagged in the #51 review (a whole-settings replacement
/// that forgets the sync, or a command that writes only one side).
extension KiwiCore {
    /// Assigns the tiling settings and mirrors the animation
    /// durations onto the engine. Every whole-settings
    /// replacement — profile apply, composed Standard, GUI
    /// live-apply — routes through here so no site can forget the
    /// sync and animate at a stale duration.
    func applyTilingSettings(_ settings: TilingSettings) {
        tiler.settings = settings
        tiler.animation.durationMS = settings.animations.durationMS
        tiler.animation.scrollDurationMS =
            settings.animations.scrollSpeedMS
    }

    /// Sets the general animation duration on both the engine and
    /// the persisted settings in lockstep. The single write path
    /// for `animations.set_duration` and its deprecated alias, so
    /// the engine/settings mirror lives in one place.
    func setAnimationDuration(_ ms: Int) {
        tiler.animation.durationMS = ms
        tiler.settings.animations.durationMS = ms
    }

    /// Sets the scrolling focus-shift speed on both the engine and
    /// the persisted settings in lockstep. The single write path
    /// for `animations.set_scroll_speed` and the deprecated
    /// `scroll.set_speed` alias.
    func setScrollSpeed(_ ms: Int) {
        tiler.animation.scrollDurationMS = ms
        tiler.settings.animations.scrollSpeedMS = ms
    }
}
