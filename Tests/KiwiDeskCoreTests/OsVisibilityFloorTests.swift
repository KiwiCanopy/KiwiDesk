import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The WindowServer clamps (almost) fully offscreen frames
/// back to its own visibility floor (#148, probed): any
/// deliberate sliver asked below it is unreachable, the ±2 pt
/// retile tolerance never passes, and every retile re-issues
/// the frame. Both slivers must sit at or above the shared
/// floor constant so the next probe updates one site.
@Suite("OS visibility floor")
struct OsVisibilityFloorTests {
    @Test("The stash peek is an achievable ask")
    func stashPeekAboveFloor() {
        #expect(
            TilingEngine.stashPeek
                >= GeometryUtils.osVisibilityFloor
        )
    }

    @Test("The scrolling edge peek is an achievable ask")
    func edgePeekAboveFloor() {
        #expect(
            ScrollingLayout.edgePeek
                >= GeometryUtils.osVisibilityFloor
        )
    }

    @Test("The floor itself matches the probed range")
    func floorMatchesProbe() {
        // 32–40 pt observed across edges; the constant is the
        // max, so every edge's ask clears its clamp.
        #expect(GeometryUtils.osVisibilityFloor == 40)
    }
}
