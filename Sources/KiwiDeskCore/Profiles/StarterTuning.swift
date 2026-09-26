import CoreGraphics
import Foundation

/// Starter layout parameter defaults tuned for screen shape (#678).
///
/// Still ONE `TilingSettings` per profile: a layout the allocator
/// places on one screen takes that screen's tuning, and everything
/// profile-wide — gaps, the minimum window size, Scrolling, which
/// leads several screens — takes the MAIN screen's (#1662).
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
    /// (#1018, #1662). Explicit rather than `.auto`, and wide
    /// enough that the Settings window, tiled right after
    /// onboarding, keeps its preview column on a 14" laptop
    /// (`StarterSlotSettingsFitTests`); the next window peeks in.
    static let standardSlot = 0.8
    /// Starter Scrolling slot fraction on ultrawide displays
    /// (#1018) — 48% of 3440 pt is a 1650 pt column. Read from the
    /// MAIN screen, so the two mixed setups are ruled: an
    /// ultrawide SECONDARY keeps `standardSlot` (and that wide
    /// column); an ultrawide MAIN imposes 30% on a laptop
    /// secondary (~518 pt — tight, above the 420 pt minimum this
    /// branch sets). One `slotSize` per profile; per-space
    /// overrides are the other answer's home.
    static let ultrawideSlot = 0.3

    /// Settings for a setup whose main screen is `mainShape`, each
    /// single-screen layout in `hosts` tuned for the screen it
    /// sits on (a layout absent from `hosts` takes the main's).
    public static func settings(
        mainShape: ScreenClass,
        hosts: [LayoutMode: ScreenClass] = [:]
    ) -> TilingSettings {
        var settings = base()
        tuneProfileWide(&settings, for: mainShape)
        tuneScrolling(&settings, for: mainShape)
        tuneStack(&settings, for: hosts[.stack] ?? mainShape)
        tuneGrid(&settings, for: hosts[.grid] ?? mainShape)
        tuneTrack(&settings, for: hosts[.track] ?? mainShape)
        return settings
    }

    private static func tuneProfileWide(
        _ settings: inout TilingSettings,
        for shape: ScreenClass
    ) {
        switch shape {
        // No App Bar switch here: `LayoutAppBar` already defaults
        // it on for monocle and scrolling, per LAYOUT, so setting
        // it would be a no-op that reads like a decision.
        case .laptop:
            settings.gapsGlobal = .uniform(6)
        case .superUltrawide, .ultrawide:
            settings.minWindowSize = 420
        case .desktop, .pivoted:
            break
        }
    }

    /// Both ultrawides centre the focused column and keep a lone
    /// window at its slot rather than filling 32:9 (#1662).
    private static func tuneScrolling(
        _ settings: inout TilingSettings,
        for shape: ScreenClass
    ) {
        switch shape {
        case .superUltrawide, .ultrawide:
            settings.scrolling.slotSize = .fraction(
                clamping: ultrawideSlot
            )
            settings.scrolling.anchor = .center
            settings.scrolling.fillWhenAlone = false
        case .pivoted:
            settings.scrolling.orientation = .vertical
        case .laptop, .desktop:
            break
        }
    }

    /// Several mains sit side by side beside a right stack; their
    /// shares are equal by the accepted #222 limitation.
    private static func tuneStack(
        _ settings: inout TilingSettings,
        for shape: ScreenClass
    ) {
        switch shape {
        case .superUltrawide:
            settings.stack.masterCount = 3
        case .ultrawide:
            settings.stack.masterCount = 2
        case .pivoted:
            settings.stack.stackPosition = .bottom
        case .laptop, .desktop:
            break
        }
    }

    private static func tuneGrid(
        _ settings: inout TilingSettings,
        for shape: ScreenClass
    ) {
        switch shape {
        case .desktop:
            settings.grid.columns = 2
            settings.grid.rows = 2
        case .pivoted:
            settings.grid.splitDirection = .vertical
        case .laptop, .superUltrawide, .ultrawide:
            break
        }
    }

    private static func tuneTrack(
        _ settings: inout TilingSettings,
        for shape: ScreenClass
    ) {
        switch shape {
        case .superUltrawide, .ultrawide:
            settings.track.autoTracks = true
        case .laptop, .desktop, .pivoted:
            break
        }
    }
}
