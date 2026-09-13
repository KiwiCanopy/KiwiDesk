import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A reorder releases the scrolling rest's recorded slot, and
/// nothing else does (#1353).
///
/// `follow` tells a focus change from a row that moved
/// underneath the focus by the recorded slot (#966); a swap
/// produces the second signal while meaning the first, and the
/// model is the one place that knows a reorder happened. The
/// control below is the case the #966 arm exists for — a
/// neighbour closing ahead of the focus — which must keep the
/// slot, or the focused window jumps on every close.
@Suite("Scroll slot release on reorder")
struct ScrollSlotReleaseTests {
    private func space() -> Space {
        Space(
            id: SpaceID(1),
            mode: .scrolling,
            windows: (1...4).map { WindowID(UInt32($0)) },
            focused: WindowID(3),
            scrollRest: ScrollRest(
                offset: -500,
                focus: WindowID(3),
                position: 1600,
                restingOn: nil
            )
        )
    }

    @Test("a swap releases the slot and keeps the offset")
    func swapReleases() {
        var space = space()
        space.swap(WindowID(3), WindowID(4))
        #expect(
            space.windows == [1, 2, 4, 3].map { WindowID(UInt32($0)) }
        )
        #expect(space.scrollRest?.slot == nil)
        #expect(space.scrollRest?.offset == -500)
    }

    @Test("a swap of two other windows releases it as well")
    func unrelatedSwapReleases() {
        // The dragged window must land where it was dropped; a
        // held focus place would shift the row under the drop.
        var space = space()
        space.swap(WindowID(1), WindowID(4))
        #expect(space.scrollRest?.slot == nil)
    }

    @Test("a neighbour closing ahead of the focus keeps the slot")
    func removeKeepsTheSlot() {
        var space = space()
        space.remove(WindowID(1))
        #expect(space.scrollRest?.slot?.window == WindowID(3))
        #expect(space.scrollRest?.slot?.position == 1600)
    }

    @Test("a swap that matches no window releases nothing")
    func missingWindowIsANoOp() {
        var space = space()
        space.swap(WindowID(3), WindowID(9))
        #expect(space.scrollRest?.slot?.window == WindowID(3))
    }
}
