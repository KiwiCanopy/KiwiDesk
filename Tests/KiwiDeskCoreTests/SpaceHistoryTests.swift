import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure history (#1655): a visit pushes and clears the forward
/// half, a step moves a cursor and never pushes, a gone Space is
/// skipped, forgotten or re-keyed.
@Suite("Space history trail (#1655)")
struct SpaceHistoryTests {
    private let key = SpaceHistory.Key.allScreens

    private func trail(_ visits: [SpaceID]) -> SpaceHistory {
        var history = SpaceHistory()
        for space in visits { history.visit(space, under: key) }
        return history
    }

    private func back(
        _ history: inout SpaceHistory,
        shown: SpaceID?,
        reachable: (SpaceID) -> Bool = { _ in true }
    ) -> SpaceID? {
        guard
            let found = history.step(
                under: key,
                by: -1,
                shown: shown,
                reachable: reachable
            )
        else { return nil }
        history.move(under: key, to: found.index)
        return found.space
    }

    @Test("2 → 5 → 3: back is 5, back is 2, forward is 5")
    func browserWalk() {
        var history = trail(["2", "5", "3"])
        #expect(back(&history, shown: "3") == "5")
        #expect(back(&history, shown: "5") == "2")
        #expect(back(&history, shown: "2") == nil)
        let forward = history.step(
            under: key,
            by: 1,
            shown: "2",
            reachable: { _ in true }
        )
        #expect(forward?.space == "5")
    }

    @Test("a landing on the cursor's entry is no visit")
    func landingIsNoVisit() {
        var history = trail(["2", "5", "3"])
        _ = back(&history, shown: "3")
        history.visit("5", under: key)
        #expect(history.entries(under: key).list == ["2", "5", "3"])
        #expect(history.entries(under: key).cursor == 1)
    }

    @Test("another visit clears the forward half")
    func visitClearsForward() {
        var history = trail(["2", "5", "3"])
        _ = back(&history, shown: "3")
        history.visit("7", under: key)
        #expect(history.entries(under: key).list == ["2", "5", "7"])
        let forward = history.step(
            under: key,
            by: 1,
            shown: "7",
            reachable: { _ in true }
        )
        #expect(forward == nil)
    }

    @Test("a gone Space is skipped, and the shown one too")
    func skipsUnreachable() {
        var history = trail(["2", "5", "2", "3"])
        #expect(
            back(&history, shown: "3", reachable: { $0 != "2" }) == "5"
        )
        var again = trail(["5", "3", "3"])
        #expect(back(&again, shown: "3") == "5")
    }

    @Test("a renumbered Space keeps its visits")
    func rekey() {
        var history = trail(["2", "12", "3"])
        history.rekey("12", to: "14")
        #expect(history.entries(under: key).list == ["2", "14", "3"])
    }

    @Test("a dropped Space leaves the trail, the cursor kept")
    func forget() {
        var history = trail(["2", "6", "2", "3"])
        history.forget("6")
        #expect(history.entries(under: key).list == ["2", "3"])
        #expect(history.entries(under: key).cursor == 1)
        history.forget("3")
        #expect(history.entries(under: key).list == ["2"])
        #expect(history.entries(under: key).cursor == 0)
    }

    @Test("a trail keeps its newest entries up to the capacity")
    func capacity() {
        let visits = (1...(SpaceHistory.capacity + 5)).map {
            SpaceID(String($0))
        }
        let history = trail(visits)
        let list = history.entries(under: key).list
        #expect(list.count == SpaceHistory.capacity)
        #expect(list.last == visits.last)
        #expect(list.first == visits[5])
    }

    @Test("a disconnected screen's trail goes")
    func keepScreens() {
        var history = SpaceHistory()
        history.visit("1", under: .screen(DisplayID(1)))
        history.visit("7", under: .screen(DisplayID(2)))
        history.keepScreens([DisplayID(1)])
        #expect(history.entries(under: .screen(DisplayID(2))).list == [])
        #expect(history.entries(under: .screen(DisplayID(1))).list == ["1"])
    }
}
