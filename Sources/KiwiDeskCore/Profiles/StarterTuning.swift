import CoreGraphics
import Foundation

/// Starter layout parameter defaults tuned for the main screen's shape (#678).
public enum StarterTuning {
    /// Baseline tuning for starter profiles.
    static func base() -> TilingSettings {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(8)
        settings.stack.masterRatio = 0.8
        settings.track.newWindow = .ownTrack
        settings.scrolling.slotSize = .fraction(
            clamping: standardSlot
        )
        return settings
    }

    /// Starter Scrolling slot fraction on standard displays
    /// (#1018). Explicit rather than `.auto` (which resolves
    /// near-full and reads as "my windows were squashed into
    /// one"): just under a half puts two slots side by side with
    /// the gap visible — the picture that teaches the mode.
    static let standardSlot = 0.48
    /// Starter Scrolling slot fraction on ultrawide displays
    /// (#1018) — 48% of 3440 pt is a 1650 pt column. Read from the
    /// MAIN screen, so the two mixed setups are ruled: an
    /// ultrawide SECONDARY keeps `standardSlot` (and that wide
    /// column); an ultrawide MAIN imposes 30% on a laptop
    /// secondary (~518 pt — tight, above the 420 pt minimum this
    /// branch sets). One `slotSize` per profile; per-space
    /// overrides are the other answer's home.
    static let ultrawideSlot = 0.3

    /// Generates settings tuned for `mainShape` screen class.
    public static func settings(
        mainShape: ScreenClass
    ) -> TilingSettings {
        var settings = base()
        switch mainShape {
        case .laptop:
            settings.gapsGlobal = .uniform(6)
            settings.appBarStyle.thickness = 28
            settings.spaceBarStyle.thickness = 28
        // Nothing here turns the App Bar on, though the design
        // card says to: `LayoutAppBar` already defaults enabled
        // for monocle and scrolling — this class's two layouts —
        // and it is a per-LAYOUT switch. Setting it here would be
        // a no-op that reads like a decision, implying a 27"
        // running Monocle should go without the bar.
        case .desktop:
            settings.grid.columns = 2
            settings.grid.rows = 2
        case .ultrawide:
            settings.stack.masterCount = 2
            settings.track.autoTracks = true
            settings.minWindowSize = 420
            settings.scrolling.slotSize = .fraction(
                clamping: ultrawideSlot
            )
        case .pivoted:
            settings.stack.stackPosition = .bottom
            settings.scrolling.orientation = .vertical
            settings.grid.splitDirection = .vertical
        }
        return settings
    }
}
