import Testing

@testable import KiwiDeskCore

/// The one hold rule both shelf sections take (#1517): every
/// render follows unless a manual scroll holds, and the hold
/// ends when the active entry changes or the section hides.
@Suite("Shelf follow rule")
struct ShelfFollowRuleTests {
    private func render(
        _ follow: inout ShelfFollow<Int>,
        _ anchor: Int?
    ) -> Bool {
        follow.follows(anchor)
    }

    @Test("Every render follows until a manual scroll")
    func followsWithoutAScroll() {
        var follow = ShelfFollow<Int>()
        #expect(render(&follow, 1))
        #expect(render(&follow, 1))
        #expect(render(&follow, nil))
    }

    @Test("A manual scroll holds until the active entry changes")
    func holdEndsOnAChange() {
        var follow = ShelfFollow<Int>()
        _ = follow.follows(1)
        follow.scrolledByHand()
        #expect(!render(&follow, 1))
        #expect(!render(&follow, 1))
        #expect(render(&follow, 2))
        #expect(render(&follow, 2))
    }

    @Test("Losing the active entry ends the hold")
    func holdEndsOnNil() {
        var follow = ShelfFollow<Int>()
        _ = follow.follows(1)
        follow.scrolledByHand()
        #expect(render(&follow, nil))
    }

    @Test("Hiding ends the hold, even for the same entry")
    func resetEndsTheHold() {
        var follow = ShelfFollow<Int>()
        _ = follow.follows(1)
        follow.scrolledByHand()
        follow.reset()
        #expect(render(&follow, 1))
    }

    /// A scroll before the first render holds nothing: the first
    /// show always follows.
    @Test("The first render follows")
    func firstRenderFollows() {
        var follow = ShelfFollow<Int>()
        follow.scrolledByHand()
        #expect(render(&follow, 1))
    }
}
