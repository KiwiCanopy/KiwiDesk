import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where the Desktops selection goes when a carry ends or the desk
/// is read again under a query, and what a click or a key from a
/// dimmed line does (#3624). The overview is
/// `DesktopsSearchTests.overview()`: under "ter" only Desktop 3's
/// first line matches.
@Suite("Desktops search settles the selection")
struct DesktopsSearchSettleTests {
    typealias Search = DesktopsSearchTests

    static func place(_ desktop: Int, _ line: Int = 0) -> DesktopsPlace {
        Search.place(desktop, line)
    }

    /// Terminal picked up under "ter", then the selection taken to
    /// Desktop 1 by a click.
    static func carrying() -> DesktopsState {
        var state = Search.state()
        state.setQuery("ter")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        state.select(window: WindowID(1), in: place(1))
        return state
    }

    @Test("putting the last window back settles the selection")
    func putBackSettles() {
        var state = Search.state()
        state.setQuery("ter")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.leaveSpace, repeated: false)
        // The standing query reaches every line during the carry.
        _ = state.press(.step(2), repeated: false)
        #expect(state.place == Self.place(4))
        _ = state.togglePick(WindowID(4))
        #expect(!state.isCarrying)
        #expect(state.place == Self.place(3))
        #expect(state.window == nil)
    }

    @Test("Esc ending a carry leaves a window the query dims")
    func cancelLeavesADimmedWindow() {
        var state = Self.carrying()
        #expect(state.window == WindowID(1))
        _ = state.press(.escape, repeated: false)
        #expect(!state.isCarrying)
        #expect(state.window == nil)
        #expect(state.place == Self.place(3))
    }

    @Test("Esc ending a carry on a matching line leaves its dimmed window")
    func cancelLeavesTheWindowOnly() {
        var state = Search.state()
        state.setQuery("No")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        // A click on 1Password, whose line matches through Notes.
        state.select(window: WindowID(1), in: Self.place(1))
        _ = state.press(.escape, repeated: false)
        #expect(!state.isCarrying)
        #expect(state.place == Self.place(1))
        #expect(state.window == nil)
    }

    @Test("during a carry the window steps stay on matches")
    func carriedWindowsStayMatchOnly() {
        var state = Search.state()
        state.setQuery("No")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        #expect(state.window == WindowID(2))
        _ = state.press(.side(1), repeated: false)
        #expect(state.window == WindowID(2))
    }

    @Test("a click acts while nothing matches; the keys beep")
    func clickSkipsTheBeep() throws {
        var state = Search.state()
        state.setQuery("zzz")
        state.select(Self.place(2))
        let target = try #require(state.target(Self.place(2)))
        #expect(state.press(.pick(moveHere: false), repeated: false) == .dead)
        #expect(state.click(.pick(moveHere: false)) == .act(.jump(target)))
    }

    @MainActor
    @Test("a model click acts while nothing matches, with no beep")
    func modelClickSkipsTheBeep() throws {
        final class Box {
            var actions: [DesktopsAction] = []
            var beeps = 0
        }
        let box = Box()
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { Search.overview() }
        model.onDesktopsAction = { box.actions.append($0) }
        model.onDeadKey = { box.beeps += 1 }
        model.setScope(.desktops)
        model.setDesktopsQuery("zzz")
        let target = try #require(model.desktops?.target(Self.place(2)))
        model.clickPlace(Self.place(2), count: 1, modifiers: [], opens: true)
        #expect(box.actions == [.jump(target)])
        #expect(box.beeps == 0)
    }

    @Test("a query with no match on a later screen settles on an earlier")
    func settleWrapsToEarlierScreens() {
        var state = Search.state()
        state.select(DesktopsPlace(screen: 1, desktop: 0, line: 0))
        state.setQuery("ter")
        #expect(state.place == Self.place(3))
    }

    @Test("⌘↓ on a dimmed line beeps; an empty one still refuses")
    func openDimmedBeeps() {
        var state = Search.state()
        state.setQuery("ter")
        state.select(Self.place(2))
        #expect(state.press(.openSpace, repeated: false) == .dead)
        #expect(!state.isInside)
        state.select(Self.place(5))
        #expect(
            state.press(.openSpace, repeated: false) == .refuse(.emptySpace)
        )
    }

    @Test("from a dimmed line a held key stops, a fresh one wraps")
    func offStopSteps() {
        var state = Search.state()
        state.setQuery("ter")
        state.select(Self.place(1))
        _ = state.press(.step(-1), repeated: true)
        #expect(state.place == Self.place(1))
        _ = state.press(.step(-1), repeated: false)
        #expect(state.place == Self.place(3))
        state.select(Self.place(4))
        _ = state.press(.step(-1), repeated: true)
        #expect(state.place == Self.place(3))
    }

    @Test("← → land on the match nearest the line kept")
    func sideLandsOnTheNearestMatch() {
        var state = Search.state()
        state.setQuery("i")
        // Mail on the other screen; Safari and Terminal here.
        state.select(DesktopsPlace(screen: 1, desktop: 0, line: 0))
        _ = state.press(.side(-1), repeated: false)
        #expect(state.place == Self.place(2))
    }

    @Test("an empty overview keeps its old answers")
    func emptyOverview() {
        var state = DesktopsStateTests.state(
            DesktopOverview(screens: [], yours: nil)
        )
        #expect(!state.matchesNothing)
        #expect(state.press(.step(1), repeated: false) == .moved)
    }

    @MainActor
    @Test("a drop's reload and a re-read settle under the query")
    func readsSettle() throws {
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { Search.overview() }
        model.setScope(.desktops)
        model.setDesktopsQuery("ter")
        let dimmed = try #require(model.desktops?.target(Self.place(1)))
        model.reloadDesktops(selecting: dimmed)
        #expect(model.desktops?.place == Self.place(3))
        model.desktops?.select(Self.place(2))
        model.refreshDesktops()
        #expect(model.desktops?.place == Self.place(3))
        #expect(model.desktops?.query == "ter")
    }
}
