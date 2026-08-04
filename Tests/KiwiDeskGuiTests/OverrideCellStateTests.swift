import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The per-row override cell's four-state wording (#678 8a, owner
/// ruling 2026-08-04). The decision is pure — this pins each of
/// the four corners so a regression to the design-literal "—
/// always on Floating" (which would hide a Floating space's
/// dormant overrides, #458 haunted tiler) reds here rather than
/// only on device.
struct OverrideCellStateTests {
    @Test("tiled space with no overrides offers to customize")
    func tiledEmpty() {
        #expect(
            OverrideCellState.resolve(count: 0, isFloating: false)
                == .customize
        )
    }

    @Test("tiled space with overrides shows the custom count")
    func tiledCount() {
        #expect(
            OverrideCellState.resolve(count: 3, isFloating: false)
                == .custom(3)
        )
    }

    /// The load-bearing corner: a Floating space that still holds
    /// overrides saved for other layouts shows the count as
    /// `.saved`, NOT `.inert` — the dormant values stay visible
    /// and reachable ("grey, don't hide").
    @Test("floating space with dormant overrides shows them saved")
    func floatingWithDormant() {
        #expect(
            OverrideCellState.resolve(count: 3, isFloating: true)
                == .saved(3)
        )
    }

    @Test("only an empty floating space is inert")
    func floatingEmptyIsInert() {
        let inert = OverrideCellState.resolve(
            count: 0,
            isFloating: true
        )
        #expect(inert == .inert)
        #expect(inert.isInert)
        // Every other state has an editor to open.
        for state: OverrideCellState in [
            .customize, .custom(1), .saved(1),
        ] {
            #expect(!state.isInert)
        }
    }
}
