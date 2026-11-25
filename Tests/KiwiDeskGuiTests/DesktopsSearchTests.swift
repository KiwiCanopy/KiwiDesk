import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side's search (#3624 ▸ Ruling): match-only keys, a
/// carry reaching every line, and a typed number naming a Desktop.
/// KiwiHub's screen has five Desktops; Desktop 3 shows its second
/// line and holds Terminal on its first. The other screen holds
/// Mail on its one Desktop.
@Suite("Desktops side search")
struct DesktopsSearchTests {
    typealias Fixture = DesktopsStateTests

    static func window(
        _ id: UInt32,
        _ app: String,
        title: String = ""
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: WindowID(id),
            pid: 900_500,
            app: app,
            title: title,
            block: nil
        )
    }

    static func overview() -> DesktopOverview {
        let desktops = [
            Fixture.desktop(
                1,
                shown: true,
                [
                    Fixture.line(
                        "1",
                        [
                            window(1, "1Password"),
                            window(2, "Notes", title: "v3"),
                        ],
                        shown: true
                    )
                ]
            ),
            Fixture.desktop(
                2,
                shown: false,
                [Fixture.line("1", [window(3, "Safari")])]
            ),
            Fixture.desktop(
                3,
                shown: false,
                [
                    Fixture.line("1", [window(4, "Terminal")]),
                    Fixture.line("2", [], shown: true),
                ]
            ),
            Fixture.desktop(
                4,
                shown: false,
                [Fixture.line("1", [window(5, "Xcode")])]
            ),
            Fixture.desktop(5, shown: false, [Fixture.line("1", [])]),
        ]
        let here = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: desktops
        )
        let other = DesktopOverview.Screen(
            display: DisplayID(2),
            name: "DELL",
            isMain: false,
            isHere: false,
            desktops: [
                Fixture.desktop(
                    1,
                    shown: true,
                    [Fixture.line("9", [window(9, "Mail")])]
                )
            ]
        )
        return DesktopOverview(screens: [here, other], yours: WindowID(1))
    }

    static func state() -> DesktopsState { Fixture.state(overview()) }

    static func place(_ desktop: Int, _ line: Int = 0) -> DesktopsPlace {
        DesktopsPlace(screen: 0, desktop: desktop - 1, line: line)
    }

    /// Every place a run of presses selects.
    static func visits(
        _ state: inout DesktopsState,
        _ keys: [JumpKey]
    ) -> Set<DesktopsPlace> {
        var seen: Set<DesktopsPlace> = []
        for key in keys {
            _ = state.press(key, repeated: false)
            if let place = state.place { seen.insert(place) }
        }
        return seen
    }

    @Test("under a query the arrows land only on matches")
    func matchOnly() {
        var state = Self.state()
        state.setQuery("ter")
        #expect(state.place == Self.place(3))
        let keys: [JumpKey] =
            Array(repeating: .step(1), count: 6)
            + Array(repeating: .step(-1), count: 6)
            + [.page(1), .page(-1), .side(1), .side(-1)]
        #expect(Self.visits(&state, keys) == [Self.place(3)])
    }

    @Test("a carry reaches every line and lifts the dimming")
    func carryReachesAll() {
        var state = Self.state()
        state.setQuery("ter")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.leaveSpace, repeated: false)
        #expect(state.isCarrying)
        let column = state.columnOrder(screen: 0)
        let keys = Array(repeating: JumpKey.step(1), count: column.count)
        #expect(Self.visits(&state, keys) == Set(column))
        #expect(column.allSatisfy(state.reaches))
        // The icons keep their emphasis.
        let safari = Self.window(3, "Safari")
        #expect(!state.matches(safari, at: Self.place(2)))
    }

    @Test("a cancelled carry leaves a dimmed line for a match")
    func cancelSettles() {
        var state = Self.state()
        state.setQuery("ter")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.leaveSpace, repeated: false)
        _ = state.press(.step(2), repeated: false)
        #expect(state.place == Self.place(4))
        _ = state.press(.escape, repeated: false)
        #expect(!state.isCarrying)
        #expect(state.place == Self.place(3))
    }

    @Test("a number selects that Desktop's landing line; ↩ jumps")
    func numberSelects() {
        var state = Self.state()
        state.setQuery("3")
        #expect(state.place == Self.place(3, 1))
        let target = state.target(state.place!)!
        #expect(target.desktop.label == 3)
        #expect(
            state.press(.pick(moveHere: false), repeated: false)
                == .act(.jump(target))
        )
        // ↓ stays among Desktop 3's lines.
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == Self.place(3, 0))
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == Self.place(3, 1))
    }

    @Test("a number is trimmed and drops leading zeros, with no 0 alias")
    func numberForms() {
        var state = Self.state()
        state.setQuery(" 03 ")
        #expect(state.search == .number(3))
        #expect(state.place == Self.place(3, 1))
        state.setQuery("0")
        #expect(state.matchesNothing)
        state.setQuery("99999999999999999999999")
        #expect(state.search == .number(nil))
        #expect(state.matchesNothing)
    }

    @Test("a number matches no window text")
    func numberIgnoresText() {
        var state = Self.state()
        state.setQuery("3")
        let notes = Self.window(2, "Notes", title: "v3")
        #expect(!state.matches(notes, at: Self.place(1)))
        #expect(!state.reaches(Self.place(1)))
        let terminal = Self.window(4, "Terminal")
        #expect(state.matches(terminal, at: Self.place(3)))
    }

    @Test("a number out of range matches nothing, and the keys beep")
    func numberOutOfRange() {
        var state = Self.state()
        state.setQuery("12")
        #expect(state.matchesNothing)
        #expect(state.place == Self.place(1))
        #expect(state.press(.pick(moveHere: false), repeated: false) == .dead)
        #expect(state.press(.pick(moveHere: true), repeated: false) == .dead)
        #expect(state.press(.follow, repeated: false) == .dead)
        #expect(state.press(.step(1), repeated: false) == .dead)
        #expect(state.press(.side(1), repeated: false) == .dead)
        #expect(state.press(.openSpace, repeated: false) == .dead)
        #expect(state.place == Self.place(1))
    }

    @Test("text starting with a digit is text")
    func digitLedText() {
        var state = Self.state()
        state.setQuery("1p")
        #expect(state.search == .text("1p"))
        #expect(state.matches(Self.window(1, "1Password"), at: Self.place(1)))
        #expect(state.place == Self.place(1))
    }

    @Test("a query keeps a matching selection and moves a dimmed one")
    func querySettles() {
        var state = Self.state()
        state.setQuery("No")
        #expect(state.place == Self.place(1))
        state.setQuery("Saf")
        #expect(state.place == Self.place(2))
        // No match in this column: the next column's.
        state.setQuery("Mail")
        #expect(state.place == DesktopsPlace(screen: 1, desktop: 0, line: 0))
    }

    @Test("clearing the query keeps the selection")
    func clearKeeps() {
        var state = Self.state()
        state.setQuery("Saf")
        state.setQuery("")
        #expect(state.place == Self.place(2))
    }

    @Test("inside a Space the window steps land only on matches")
    func windowStepsMatchOnly() {
        var state = Self.state()
        state.setQuery("pass")
        _ = state.press(.openSpace, repeated: false)
        #expect(state.window == WindowID(1))
        _ = state.press(.side(1), repeated: false)
        #expect(state.window == WindowID(1))
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == Self.place(1))
    }

    @Test("a click still reaches a dimmed line")
    func clickReachesDimmed() {
        var state = Self.state()
        state.setQuery("ter")
        state.select(Self.place(4))
        #expect(state.place == Self.place(4))
        // The next arrow returns to the matches.
        _ = state.press(.step(-1), repeated: false)
        #expect(state.place == Self.place(3))
    }
}
