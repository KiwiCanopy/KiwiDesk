import CoreGraphics
import Foundation

/// How a starter setup's layouts are tuned for the hardware
/// (#678 Phase 4 pass 11, turn 15b).
///
/// **The MAIN screen's class decides, for the whole profile.**
/// That is not a preference: `TilingSettings` is profile-wide, so
/// a laptop beside a 27" has exactly one gap value and one stack
/// ratio to give, and the only question is which screen names
/// them. Per-space overrides are what express the rest, and are
/// where a user who wants a different answer on one screen goes.
/// Do not read this as a per-display seam waiting to be built —
/// making it one would put a second config behind every value the
/// Settings window shows.
public enum StarterTuning {
    /// The beginner tuning every class starts from: a comfortable
    /// gap, the stack's single-master 80/20 split, and track's
    /// new-window-opens-its-own-track.
    static func base() -> TilingSettings {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(8)
        settings.stack.masterRatio = 0.8
        settings.track.newWindow = .ownTrack
        return settings
    }

    /// The base, tuned for the main screen's shape.
    public static func settings(
        mainShape: ScreenClass
    ) -> TilingSettings {
        var settings = base()
        switch mainShape {
        case .laptop:
            // A laptop cannot spare 40 pt of chrome per edge.
            settings.gapsGlobal = .uniform(6)
            settings.appBarStyle.thickness = 28
            settings.spaceBarStyle.thickness = 28
        // Nothing here turns the App Bar on, though turn 15b's
        // laptop card says to. It is already on: `LayoutAppBar`
        // defaults `enabled` true for monocle and scrolling —
        // which are exactly this class's two layouts — and it is
        // a per-LAYOUT switch, so it follows the layout that
        // hides windows rather than the size of the screen.
        // Setting it here would have been a no-op that read like
        // a decision, and it would have implied the wrong model:
        // that a 27" running Monocle should go without the bar.
        case .desktop:
            // At 2560 pt a three-column grid gives 850 pt cells,
            // under a comfortable browser width — so two columns,
            // and Dynamic grows the grid as windows arrive rather
            // than committing up front.
            settings.grid.columns = 2
            settings.grid.rows = 2
        case .ultrawide:
            // One master on a 3440 pt screen is an absurdly wide
            // pane; the auto limit and a bigger minimum keep
            // tracks readable rather than multiplying.
            settings.stack.masterCount = 2
            settings.track.autoTracks = true
            settings.minWindowSize = 420
        case .pivoted:
            // Everything that assumes width has to flip. The
            // Space Bar needs no move — its default edge is
            // already `.top`, which is the horizontal edge a
            // pivoted screen wants, since a vertical bar would
            // eat the narrow axis.
            settings.stack.stackPosition = .bottom
            settings.scrolling.orientation = .vertical
            settings.grid.splitDirection = .vertical
        }
        return settings
    }
}
