import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktops side's selection and keys (#1229), pure: places
/// before windows, the carry, Esc's layers, search order. Two
/// screens; the second is KiwiHub's and shows Desktop 1's Space "1".
@Suite("Desktops side state")
struct DesktopsStateTests {
    static func window(
        _ id: UInt32,
        _ app: String,
        block: DesktopOverview.CarryBlock? = nil
    ) -> DesktopOverview.Window {
        DesktopOverview.Window(
            id: WindowID(id),
            pid: 900_400,
            app: app,
            title: "",
            block: block
        )
    }

    static func line(
        _ space: String,
        _ windows: [DesktopOverview.Window],
        shown: Bool = false,
        last: UInt32? = nil
    ) -> DesktopOverview.SpaceLine {
        DesktopOverview.SpaceLine(
            space: SpaceID(space),
            mode: .bsp,
            isShown: shown,
            marker: nil,
            windows: windows,
            lastFocused: last.map(WindowID.init)
        )
    }

    static func desktop(
        _ label: Int,
        shown: Bool,
        _ spaces: [DesktopOverview.SpaceLine]
    ) -> DesktopOverview.Desktop {
        DesktopOverview.Desktop(
            native: UInt64(label),
            label: label,
            number: label,
            isShown: shown,
            profile: nil,
            spaces: spaces
        )
    }

    /// KiwiHub's sheet cap on a 1440×900 screen, which the slot pins
    /// in this suite and `DesktopsGeometryTests` reason from.
    static let cap: CGFloat = 411

    /// The state on a 600 pt panel: five icon slots on the KiwiHub
    /// screen's row, so its seven-window line scrolls.
    static func state(_ overview: DesktopOverview) -> DesktopsState {
        DesktopsState(
            overview: overview,
            geometry: DesktopsGeometry(
                overview: overview,
                width: 600,
                cap: cap
            )
        )
    }

    static func overview(yours: UInt32? = 1) -> DesktopOverview {
        let other = DesktopOverview.Screen(
            display: DisplayID(2),
            name: "DELL",
            isMain: false,
            isHere: false,
            desktops: [
                desktop(1, shown: true, [line("5", [window(9, "Mail")])])
            ]
        )
        let here = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [
                desktop(
                    1,
                    shown: true,
                    [
                        line(
                            "1",
                            (1...7).map { window(UInt32($0), "App \($0)") },
                            shown: true,
                            last: 6
                        ),
                        line("2", []),
                    ]
                ),
                desktop(
                    2,
                    shown: false,
                    [
                        line(
                            "1",
                            [window(20, "Safari")]
                        ),
                        line("2", [], shown: true),
                    ]
                ),
            ]
        )
        return DesktopOverview(
            screens: [other, here],
            yours: yours.map(WindowID.init)
        )
    }

    @Test("opens on the line the KiwiHub screen shows")
    func opensHere() {
        let state = Self.state(Self.overview())
        #expect(state.place == DesktopsPlace(screen: 1, desktop: 0, line: 0))
    }

    @Test("↑↓ walk lines and screens; a held key stops at an end")
    func verticalSteps() {
        var state = Self.state(Self.overview())
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == DesktopsPlace(screen: 1, desktop: 0, line: 1))
        _ = state.press(.step(1), repeated: true)
        #expect(state.place?.line == 1)
        _ = state.press(.step(1), repeated: false)
        #expect(state.place == DesktopsPlace(screen: 0, desktop: 0, line: 0))
    }

    @Test("⌘↓ opens on the last-focused window, scrolled into view")
    func openSpace() {
        var state = Self.state(Self.overview())
        #expect(state.press(.openSpace, repeated: false) == .moved)
        #expect(state.window == WindowID(6))
        #expect(state.offset(state.place!) == 1)
        #expect(state.hidden(state.place!).before == 1)
        _ = state.press(.leaveSpace, repeated: false)
        #expect(!state.isInside)
    }

    @Test("an empty Space does not open")
    func emptySpaceRefuses() {
        var state = Self.state(Self.overview())
        _ = state.press(.step(1), repeated: false)
        #expect(
            state.press(.openSpace, repeated: false) == .refuse(.emptySpace)
        )
    }

    @Test("↩ jumps, ⇧↩ moves yours there, ⌃↩ also follows")
    func placePicks() {
        var state = Self.state(Self.overview())
        _ = state.press(.side(1), repeated: false)
        let target = state.target(state.place!)!
        #expect(target.desktop.label == 2)
        #expect(
            state.press(.pick(moveHere: false), repeated: false)
                == .act(.jump(target))
        )
        #expect(
            state.press(.pick(moveHere: true), repeated: false)
                == .act(.moveYours(target, follow: false))
        )
        #expect(
            state.press(.follow, repeated: false)
                == .act(.moveYours(target, follow: true))
        )
        var none = Self.state(Self.overview(yours: nil))
        #expect(
            none.press(.pick(moveHere: true), repeated: false)
                == .refuse(.nothingYours)
        )
    }

    @Test("windows are carried in pick order and dropped where chosen")
    func carry() {
        var state = Self.state(Self.overview())
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.side(-1), repeated: false)
        _ = state.press(.pickUp, repeated: false)
        #expect(state.carried == [WindowID(6), WindowID(5)])
        _ = state.press(.leaveSpace, repeated: false)
        _ = state.press(.step(1), repeated: false)
        let target = state.target(state.place!)!
        #expect(
            state.press(.follow, repeated: false)
                == .act(
                    .drop([WindowID(6), WindowID(5)], target, follow: true)
                )
        )
    }

    @Test("a window on a hidden Desktop is picked up (#3171)")
    func hiddenWindowPicks() {
        var state = Self.state(Self.overview())
        _ = state.press(.side(1), repeated: false)
        _ = state.press(.openSpace, repeated: false)
        #expect(state.press(.pickUp, repeated: false) == .moved)
        #expect(state.carried == [WindowID(20)])
    }

    @Test("a full-screen window is not picked up")
    func fullScreenRefuses() {
        let blocked = Self.window(30, "Movie", block: .fullScreen)
        let screen = DesktopOverview.Screen(
            display: DisplayID(1),
            name: "Built-in",
            isMain: true,
            isHere: true,
            desktops: [
                Self.desktop(1, shown: true, [Self.line("1", [blocked])])
            ]
        )
        var state = Self.state(DesktopOverview(screens: [screen], yours: nil))
        _ = state.press(.openSpace, repeated: false)
        #expect(
            state.press(.pickUp, repeated: false)
                == .refuse(.carryBlocked(blocked, .fullScreen))
        )
        #expect(!state.isCarrying)
    }

    @Test("a drop where every window already is refuses")
    func dropInPlace() {
        var state = Self.state(Self.overview())
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.leaveSpace, repeated: false)
        #expect(
            state.press(.pick(moveHere: false), repeated: false)
                == .refuse(.alreadyThere("1"))
        )
    }

    @Test("Esc steps back: carry, Space, search, then close")
    func escapeLayers() {
        var state = Self.state(Self.overview())
        state.setQuery("App")
        _ = state.press(.openSpace, repeated: false)
        _ = state.press(.pickUp, repeated: false)
        _ = state.press(.escape, repeated: false)
        #expect(!state.isCarrying && state.isInside)
        _ = state.press(.escape, repeated: false)
        #expect(!state.isInside && state.query == "App")
        _ = state.press(.escape, repeated: false)
        #expect(state.query.isEmpty)
        #expect(state.press(.escape, repeated: false) == .close)
    }

    @Test("matches move to the front of their Space; nothing hides")
    func searchOrder() {
        var state = Self.state(Self.overview())
        state.setQuery("App 7")
        let drawn = state.ordered(state.place!).map(\.id.raw)
        #expect(drawn == [7, 1, 2, 3, 4, 5, 6])
        let empty = DesktopsPlace(screen: 1, desktop: 0, line: 1)
        #expect(!state.hasMatch(empty))
    }

    @Test("⌘ digits name the selected row's Desktops; ⇧ moves yours")
    func digits() {
        var state = Self.state(Self.overview())
        let second = Self.overview().screens[1].desktops[1]
        #expect(
            state.press(.quick(1, moveHere: false), repeated: false)
                == .act(.jumpDesktop(second))
        )
        #expect(
            state.press(.quick(1, moveHere: true), repeated: false)
                == .act(.moveYoursToDesktop(second))
        )
        #expect(
            state.press(.quick(4, moveHere: false), repeated: false) == .dead
        )
    }
}
