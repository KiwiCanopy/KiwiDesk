import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The WindowServer clamps (almost) fully offscreen frames
/// back to its own visibility floor (#148, probed): a deliberate
/// sliver asked below it on a *single* edge is unreachable, the
/// ±2 pt retile tolerance never passes, and every retile
/// re-issues the frame.
///
/// The stash peek is asymmetric (#410, verified on device). Its
/// **width** is a bare 1 pt: a corner overhang hangs off *two*
/// edges, which escapes the single-edge floor. Its **height**
/// stays above the floor (`floor + 8`): parking at the bottom
/// puts the title bar at the screen edge and macOS lifts the
/// window to keep it grabbable — a clamp the vertical can't
/// escape (a 1 pt ask floored to ~floor anyway, and thrashed the
/// retile). The scrolling edge peek is a single-edge overhang and
/// must likewise stay above the floor.
@Suite("OS visibility floor")
struct OsVisibilityFloorTests {
    @Test("The stash height is an achievable ask")
    func stashHeightAboveFloor() {
        #expect(
            TilingEngine.stashPeekY
                > WindowServerFacts.visibilityFloor
        )
    }

    @Test("The stash width is a 1 pt corner remnant")
    func stashWidthIsCornerSliver() {
        // Below the single-edge floor on purpose: a corner (two
        // edge) overhang escapes it horizontally (#410).
        #expect(TilingEngine.stashPeekX == 1)
    }

    @Test("The scrolling edge peek is an achievable ask")
    func edgePeekAboveFloor() {
        #expect(
            ScrollingLayout.edgePeek
                > WindowServerFacts.visibilityFloor
        )
    }

    @Test("The floor stays in the plausible probe band")
    func floorSanityBand() {
        // Not a pin — a re-probe after a macOS update is
        // expected to edit the constant (one site). This only
        // catches a fat-fingered edit.
        let floor = WindowServerFacts.visibilityFloor
        #expect(floor > 0 && floor < 100)
    }
}
