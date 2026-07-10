import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The WindowServer clamps (almost) fully offscreen frames
/// back to its own visibility floor (#148, probed): any
/// deliberate sliver asked below it is unreachable, the ±2 pt
/// retile tolerance never passes, and every retile re-issues
/// the frame. Both slivers must sit strictly above the shared
/// floor constant — the floor is approximate, the margin
/// absorbs that — so the next probe updates one site.
@Suite("OS visibility floor")
struct OsVisibilityFloorTests {
    @Test("The stash peek is an achievable ask")
    func stashPeekAboveFloor() {
        #expect(
            TilingEngine.stashPeek
                > WindowServerFacts.visibilityFloor
        )
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
