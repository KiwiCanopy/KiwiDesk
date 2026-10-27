import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Space row's override count state (#678 8a, #2674, owner ruling
/// 2026-08-04). The decision is pure — this pins each corner so a
/// regression to the design-literal "— always on Floating" (which
/// would hide a Floating space's dormant overrides, #458 haunted
/// tiler, and its live minimum size, #2422) reds here rather than
/// only on device.
struct OverrideCellStateTests {
    @Test("tiled space with no overrides offers to customize")
    func tiledEmpty() {
        #expect(
            OverrideCellState.resolve(count: 0, live: 0, isFloating: false)
                == .customize
        )
    }

    @Test("tiled space with overrides shows the custom count")
    func tiledCount() {
        #expect(
            OverrideCellState.resolve(count: 3, live: 0, isFloating: false)
                == .custom(3)
        )
    }

    /// The load-bearing corner: a Floating space that still holds
    /// overrides saved for other layouts shows the count as
    /// `.saved` — the dormant values stay visible and reachable
    /// ("grey, don't hide").
    @Test("floating space with dormant overrides shows them saved")
    func floatingWithDormant() {
        #expect(
            OverrideCellState.resolve(count: 3, live: 0, isFloating: true)
                == .saved(3)
        )
    }

    /// A Space's own minimum size floors its floats (#2422), so a
    /// Floating space offers the editor and counts that value live.
    @Test("floating space keeps its editor and its live minimum")
    func floatingStaysReachable() {
        #expect(
            OverrideCellState.resolve(count: 0, live: 0, isFloating: true)
                == .customize
        )
        #expect(
            OverrideCellState.resolve(count: 3, live: 1, isFloating: true)
                == .custom(3)
        )
    }

    @Test("only the Space's own minimum size is live while floating")
    func liveCountIsTheMinimum() {
        var settings = TilingSettings()
        let space = SpaceID("2")
        settings.gapsOverride[space] = .uniform(4)
        #expect(settings.floatingLiveOverrideCount(for: space) == 0)
        settings.minWindowSizeOverride[space] = 200
        #expect(settings.floatingLiveOverrideCount(for: space) == 1)
    }
}
