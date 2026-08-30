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

    /// Starter Scrolling slot fraction on standard displays (48%, #1018).
    static let standardSlot = 0.48
    /// Starter Scrolling slot fraction on ultrawide displays (30%, #1018).
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
