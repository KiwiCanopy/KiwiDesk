import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// ↑ ↓ inside a Space take the places' route (#3169): a line with
/// windows is re-entered on the slot the selection left, an empty
/// line is selected and leaves the Space, and the wrap is #2897's.
@Suite("Desktops side ↑↓ inside a Space")
struct DesktopsStepInsideTests {
    typealias Fixture = DesktopsStateTests

    /// One screen, one Desktop: A holds 1…3 (last focused 2),
    /// B holds 4…6, C is empty.
    static func overview() -> DesktopOverview {
        let ids: (ClosedRange<UInt32>) -> [DesktopOverview.Window] = {
            $0.map { Fixture.window($0, "App \($0)") }
        }
        let desktop = Fixture.desktop(
            1,
            shown: true,
            [
                Fixture.line("A", ids(1...3), shown: true, last: 2),
                Fixture.line("B", ids(4...6)),
                Fixture.line("C", []),
            ]
        )
        let screen = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [desktop]
        )
        return DesktopOverview(screens: [screen], yours: nil)
    }

    static func opened() -> DesktopsState {
        var state = DesktopsState(overview: overview())
        _ = state.press(.openSpace, repeated: false)
        return state
    }

    @Test("a line with windows is re-entered on the same slot")
    func keepsTheSlot() {
        var state = Self.opened()
        #expect(state.window == WindowID(2))
        #expect(state.press(.step(1), repeated: false) == .moved)
        #expect(state.place?.line == 1)
        #expect(state.window == WindowID(5))
    }

    @Test("an empty line is selected, leaving the Space")
    func emptyLineLeaves() {
        var state = Self.opened()
        _ = state.press(.step(1), repeated: false)
        _ = state.press(.step(1), repeated: false)
        #expect(state.place?.line == 2)
        #expect(!state.isInside)
        #expect(state.press(.leaveSpace, repeated: false) == .dead)
    }

    @Test("a fresh press wraps, a held key stops at the end")
    func wrapsOnAFreshPress() {
        var state = Self.opened()
        _ = state.press(.step(-1), repeated: true)
        #expect(state.place?.line == 0)
        #expect(state.window == WindowID(2))
        _ = state.press(.step(-1), repeated: false)
        #expect(state.place?.line == 2)
        #expect(!state.isInside)
    }

    @Test("⌘↑ from inside still leaves the Space")
    func leaveFromInside() {
        var state = Self.opened()
        #expect(state.press(.leaveSpace, repeated: false) == .moved)
        #expect(!state.isInside)
    }
}
