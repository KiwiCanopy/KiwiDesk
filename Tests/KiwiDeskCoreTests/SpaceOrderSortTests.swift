import Testing

@testable import KiwiDeskCore

/// `WorkspaceManager.sortInPlace` (#1994): the temporary Spaces
/// line up by number within their own screen's slots, every other
/// Space keeping the place it was given — judged on each screen's
/// row, `spaces(on:)`, which is what a bar draws.
@Suite("Temporary Space sort (#1994)")
struct SpaceOrderSortTests {
    private let a = DisplayID(1)
    private let b = DisplayID(2)

    /// Builds the order from `(id, screen)` pairs, in that order.
    private func workspaces(
        _ layout: [(Int, DisplayID)]
    ) -> WorkspaceManager {
        var w = WorkspaceManager()
        for (id, screen) in layout { w.assign(SpaceID(id), to: screen) }
        return w
    }

    @Test("one screen: the sorted ids take the slots they held")
    func sortsWithinTheirSlots() {
        var w = workspaces([(8, a), (3, a), (6, a), (1, a)])
        let ids: Set = [SpaceID(8), SpaceID(6), SpaceID(1)]
        let moved = w.sortInPlace(ids)
        #expect(moved)
        #expect(w.spaces(on: a).map(\.raw) == ["1", "3", "6", "8"])
        let again = w.sortInPlace(ids)
        #expect(!again, "a sorted order reports no move")
    }

    /// A swap across screens would carry 9 past held 20 on screen
    /// A and 7 past declared 4 on screen B.
    @Test("two screens: no Space passes another on its own screen")
    func neverCrossesAScreen() {
        var w = workspaces([
            (1, a), (9, a), (20, a), (4, b), (7, b),
        ])
        let moved = w.sortInPlace([SpaceID(9), SpaceID(7)])
        #expect(!moved)
        #expect(w.spaces(on: a).map(\.raw) == ["1", "9", "20"])
        #expect(w.spaces(on: b).map(\.raw) == ["4", "7"])
    }
}
