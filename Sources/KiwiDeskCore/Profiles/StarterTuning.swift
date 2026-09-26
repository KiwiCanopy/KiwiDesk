import CoreGraphics
import Foundation

/// Starter layout parameter defaults tuned for screen shape (#678).
///
/// Still ONE `TilingSettings` per profile: each layout takes the
/// tuning of the screen `StarterSetup.hosts` names for it, and
/// what no layout owns —
/// gaps, the minimum window size — takes the MAIN screen's
/// (#1662).
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
    /// onboarding, keeps its preview column on every MacBook's
    /// default resolution (`StarterSlotSettingsFitTests`); the next
    /// window peeks in.
    static let standardSlot = 0.85
    /// Starter Scrolling slot fraction on both ultrawides (#1018):
    /// three readable columns. Read from the screen Scrolling first
    /// lands on, so an ultrawide hosting it imposes 30% on a laptop
    /// that also scrolls (~518 pt — tight, above the 420 pt
    /// minimum this branch sets). One `slotSize` per profile.
    static let ultrawideSlot = 0.3

    /// Settings for a setup whose main screen is `mainShape`, each
    /// layout in `hosts` tuned for the screen it first lands on (a
    /// layout absent from `hosts` takes the main's).
    public static func settings(
        mainShape: ScreenClass,
        hosts: [LayoutMode: ScreenClass]
    ) -> TilingSettings {
        var settings = base()
        tuneProfileWide(&settings, for: mainShape)
        tuneScrolling(&settings, for: hosts[.scrolling] ?? mainShape)
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
        case .pivoted, .laptop, .desktop:
            break
        }
        settings.scrolling.orientation = scrollingOrientation(for: shape)
    }

    /// The one answer to which way a screen of `shape` scrolls; the
    /// per-space direction overrides read it too.
    static func scrollingOrientation(
        for shape: ScreenClass
    ) -> ScrollingParams.Orientation {
        shape == .pivoted ? .vertical : .horizontal
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
