import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A query edited during a carry steers it like a search, while one
/// standing at the pick-up reaches every line (#3624). The overview
/// is `DesktopsSearchTests.overview()`: Terminal sits on Desktop 3's
/// first line and Safari on Desktop 2's.
@Suite("Desktops search typed during a carry")
struct DesktopsCarryQueryTests {
    typealias Search = DesktopsSearchTests

    static func place(_ desktop: Int, _ line: Int = 0) -> DesktopsPlace {
        Search.place(desktop, line)
    }

    /// Terminal picked up under "ter", the selection then taken down
    /// to Desktop 4, which the standing query would dim.
    static func carrying() -> DesktopsState {
        var state = Search.state()
        state.setQuery("ter")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.leaveSpace, repeated: false)
        _ = state.press(.step(2), repeated: false)
        return state
    }

    @Test("a query standing at the pick-up reaches every line")
    func standingQueryLifts() {
        let state = Self.carrying()
        #expect(state.place == Self.place(4))
        #expect(!state.queryLeadsCarry)
        #expect(state.reaches(Self.place(4)))
    }

    @Test("a query edited during the carry steers and dims; ↩ drops")
    func editedQuerySteers() throws {
        var state = Self.carrying()
        state.setQuery("Saf")
        #expect(state.queryLeadsCarry)
        #expect(state.place == Self.place(2))
        #expect(!state.reaches(Self.place(4)))
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == Self.place(2))
        let target = try #require(state.target(Self.place(2)))
        #expect(
            state.press(.pick(moveHere: false), repeated: false)
                == .act(.drop([WindowID(4)], target, follow: false))
        )
    }

    @Test("an edited query matching nothing beeps the drop")
    func editedQueryMatchingNothing() {
        var state = Self.carrying()
        state.setQuery("zzz")
        #expect(state.matchesNothing)
        #expect(state.press(.pick(moveHere: false), repeated: false) == .dead)
    }

    @Test("the next pick-up lifts the query again")
    func nextPickUpLifts() {
        var state = Self.carrying()
        state.setQuery("Saf")
        state.select(window: WindowID(3), in: Self.place(2))
        _ = state.click(.pickUp)
        #expect(state.carried == [WindowID(4), WindowID(3)])
        #expect(!state.queryLeadsCarry)
        #expect(state.reaches(Self.place(4)))
    }

    @Test("Esc clears a query typed during the carry, then the carry")
    func escapeClearsTheQueryFirst() {
        var state = Self.carrying()
        state.setQuery("Saf")
        _ = state.press(.escape, repeated: false)
        #expect(state.isCarrying)
        #expect(state.query.isEmpty)
        #expect(!state.queryLeadsCarry)
        _ = state.press(.escape, repeated: false)
        #expect(!state.isCarrying)
    }

    @Test("with nothing carried, typing leads nothing and Esc leaves")
    func noCarryNoLead() {
        var state = Search.state()
        state.setQuery("ter")
        #expect(!state.queryLeadsCarry)
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.escape, repeated: false)
        #expect(!state.isInside)
        #expect(state.query == "ter")
    }

    @Test("the carry's end ends the query's lead")
    func carryEndResets() {
        var state = Self.carrying()
        state.setQuery("Saf")
        state.cancelCarry()
        #expect(!state.queryLeadsCarry)
        // The query still dims as an ordinary search.
        #expect(!state.reaches(Self.place(4)))
    }
}
