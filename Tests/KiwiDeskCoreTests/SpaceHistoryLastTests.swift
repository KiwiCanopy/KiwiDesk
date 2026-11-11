import Foundation
import Testing

@testable import KiwiDeskCore

/// `SpaceHistory.last` (#3206): the Space the cursor left, which a
/// Back moves too, so a toggle after a Back lands where you came
/// from rather than one step further back.
@Suite("Space history last")
struct SpaceHistoryLastTests {
    private let key = SpaceHistory.Key.allScreens

    private func trail(_ visits: [SpaceID]) -> SpaceHistory {
        var history = SpaceHistory()
        for space in visits { history.visit(space, under: key) }
        return history
    }

    private func last(
        _ history: SpaceHistory,
        shown: SpaceID?,
        reachable: (SpaceID) -> Bool = { _ in true }
    ) -> SpaceID? {
        history.last(under: key, shown: shown, reachable: reachable)
    }

    @Test("toggling visits 1, 2, 1, 2")
    func toggles() {
        var history = trail(["1", "2"])
        for expected: SpaceID in ["1", "2", "1", "2"] {
            let shown = history.entries(under: key).list.last
            #expect(last(history, shown: shown) == expected)
            history.visit(expected, under: key)
        }
    }

    @Test("after a Back, last is the Space the Back left")
    func backThenLast() {
        var history = trail(["A", "B", "C"])
        let found = history.step(
            under: key,
            by: -1,
            shown: "C",
            reachable: { _ in true }
        )
        #expect(found?.space == "B")
        history.move(under: key, to: found!.index)
        #expect(last(history, shown: "B") == "C")
    }

    @Test("an unreachable last falls back to the nearest entry back")
    func unreachableFallsBack() {
        let history = trail(["1", "2", "3"])
        #expect(last(history, shown: "3") == "2")
        #expect(
            last(history, shown: "3", reachable: { $0 != "2" }) == "1"
        )
        #expect(last(history, shown: "3", reachable: { $0 == "3" }) == nil)
    }

    @Test("a forgotten last falls back; a renumbered one follows")
    func forgetAndRekey() {
        var history = trail(["1", "2", "3"])
        history.rekey("2", to: "9")
        #expect(last(history, shown: "3") == "9")
        history.forget("9")
        #expect(last(history, shown: "3") == "1")
    }

    @Test("an empty trail has no last")
    func emptyTrail() {
        #expect(last(SpaceHistory(), shown: "1") == nil)
        #expect(last(trail(["1"]), shown: "1") == nil)
    }
}
