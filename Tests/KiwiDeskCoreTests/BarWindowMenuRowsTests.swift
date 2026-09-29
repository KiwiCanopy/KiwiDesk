import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The window rows of an app glyph's and an App Bar item's menu
/// (#1518, the owner's rulings of 2026-09-28 and 2026-09-29): Move
/// to Current Space on the Space Bar only, greyed where the window
/// already is; Float or Tile by the window's own setting; per-window
/// submenus for a glyph or group standing for several; Quit greyed
/// for Finder and KiwiDesk. Every row acts through the public verb.
@Suite("Bar window menu rows", .serialized)
@MainActor
struct BarWindowMenuRowsTests {
    private let display = DisplayID(7)
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Windows 1–3 of "Safari" (pid 41), titled, on Space 1, then
    /// windows 2 and 3 moved to Space 2 by id; Space 1 is active.
    private func seededCore() -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-win-menu-\(UUID())")
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: display,
                name: "Desk",
                frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
            )
        )
        core.state.workspaces.assign(one, to: display)
        core.state.workspaces.assign(two, to: display)
        core.state.workspaces.activate(one)
        for raw in [UInt32(1), 2, 3] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 41,
                        appName: "Safari",
                        appBundleID: "com.apple.safari",
                        title: "Page \(raw)"
                    )
                )
            )
        }
        for raw in [2.0, 3.0] {
            core.execute("move_to_space", args: [.string("2"), .number(raw)])
        }
        #expect(core.state.workspaces.space(of: WindowID(2)) == two)
        return core
    }

    private func titles(_ rows: [BarMenuRow]) -> [String] {
        rows.map { $0.isSeparator ? "—" : $0.title }
    }

    private func submenu(_ row: BarMenuRow) -> [BarMenuRow] {
        guard case .submenu(let rows) = row.kind else {
            Issue.record("\(row.title) is not a submenu")
            return []
        }
        return rows
    }

    private func perform(_ row: BarMenuRow) {
        guard case .action(let perform) = row.kind else {
            Issue.record("\(row.title) is not an action")
            return
        }
        perform()
    }

    private let shelf = [
        "KiwiShelf Settings…", "Looks…", "Advanced Colors…",
    ]

    @Test("a one-window glyph offers move, float and quit")
    func glyphRows() {
        let core = seededCore()
        let rows = core.barMenuRows(.glyph([WindowID(2)]))
        #expect(
            titles(rows)
                == [
                    "Move to Current Space", "Float Window", "—",
                    "Quit Safari", "—",
                ] + shelf
        )
    }

    @Test("an App Bar item offers no move")
    func appItemHasNoMove() {
        let core = seededCore()
        let rows = core.barMenuRows(.appItem([WindowID(1)]))
        #expect(
            titles(rows)
                == ["Float Window", "—", "Quit Safari", "—"] + shelf
        )
    }

    @Test("Move to Current Space moves the window to the focused Space")
    func moveMovesHere() {
        let core = seededCore()
        let move = core.barMenuRows(.glyph([WindowID(2)]))[0]
        #expect(move.enabled)
        perform(move)
        #expect(core.state.workspaces.space(of: WindowID(2)) == one)
    }

    @Test("Move is greyed for a window already in the focused Space")
    func moveGreyedHere() {
        let core = seededCore()
        let move = core.barMenuRows(.glyph([WindowID(1)]))[0]
        #expect(!move.enabled)
    }

    @Test("the float row follows the window's own setting")
    func floatFollowsState() {
        let core = seededCore()
        let float = core.barMenuRows(.appItem([WindowID(1)]))[0]
        perform(float)
        #expect(core.state.windows[WindowID(1)]?.isFloating == true)
        #expect(core.state.windows[WindowID(2)]?.isFloating == false)
        let tile = core.barMenuRows(.appItem([WindowID(1)]))[0]
        #expect(tile.title == "Tile Window")
        perform(tile)
        #expect(core.state.windows[WindowID(1)]?.isFloating == false)
    }

    /// A glyph standing for several windows names each one: the
    /// move and float rows open submenus of titles, and a pick acts
    /// on that window alone.
    @Test("a multi-window glyph names each window in submenus")
    func multiGlyphSubmenus() {
        let core = seededCore()
        let windows = [WindowID(2), WindowID(3)]
        let rows = core.barMenuRows(.glyph(windows))
        let move = submenu(rows[0])
        #expect(titles(move) == ["Page 2", "Page 3"])
        #expect(move.allSatisfy { $0.enabled })
        perform(move[1])
        #expect(core.state.workspaces.space(of: WindowID(3)) == one)
        #expect(core.state.workspaces.space(of: WindowID(2)) == two)
        let float = submenu(rows[1])
        #expect(float.map(\.checked) == [false, false])
        perform(float[0])
        #expect(core.state.windows[WindowID(2)]?.isFloating == true)
        #expect(core.state.windows[WindowID(3)]?.isFloating == false)
        let again = submenu(core.barMenuRows(.glyph(windows))[1])
        #expect(again.map(\.checked) == [true, false])
    }

    @Test("a collapsed App Bar group opens a float submenu, no move")
    func appGroupSubmenu() {
        let core = seededCore()
        let rows = core.barMenuRows(.appItem([WindowID(2), WindowID(3)]))
        #expect(titles(rows).first == "Float Window")
        #expect(titles(submenu(rows[0])) == ["Page 2", "Page 3"])
    }

    @Test("Quit terminates the app; greyed for Finder and KiwiDesk")
    func quitRow() {
        let core = seededCore()
        var quit: [pid_t] = []
        core.shelves.contextMenus.terminateApp = { quit.append($0) }
        let row = core.barMenuRows(.appItem([WindowID(1)]))[2]
        #expect(row.enabled)
        perform(row)
        #expect(quit == [41])
        let own = ProcessInfo.processInfo.processIdentifier
        for (raw, pid, bundle) in [
            (UInt32(8), pid_t(7), "com.apple.finder"),
            (UInt32(9), own, "com.kiwicanopy.kiwidesk"),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid,
                        appName: "App",
                        appBundleID: bundle
                    )
                )
            )
            let rows = core.barMenuRows(.appItem([WindowID(raw)]))
            #expect(!rows[2].enabled, "\(bundle)")
        }
    }

    /// "Current Space" is the Space holding the system focus, not
    /// the one the chip's own screen shows: a glyph on a second
    /// screen's shown Space moves its window to the FOCUSED Space.
    @Test("Move targets the focused Space, not the chip's screen")
    func moveTargetsTheFocusedSpace() {
        let core = seededCore()
        let other = DisplayID(8)
        core.state.workspaces.upsertDisplay(
            Display(
                id: other,
                name: "Side",
                frame: CGRect(x: 1000, y: 0, width: 800, height: 600)
            )
        )
        core.state.workspaces.assign(two, to: other)
        core.state.workspaces.show(two, on: other)
        #expect(core.state.workspaces.currentSpace(on: other) == two)
        let move = core.barMenuRows(.glyph([WindowID(2)]))[0]
        #expect(move.enabled)
        perform(move)
        #expect(core.state.workspaces.space(of: WindowID(2)) == one)
    }

    @Test("Move is greyed where the sticky gate would refuse it")
    func moveGreyedForSticky() {
        let core = seededCore()
        core.state.setSticky(WindowID(2), .global)
        let move = core.barMenuRows(.glyph([WindowID(2)]))[0]
        #expect(!move.enabled)
    }

    @Test("a submenu whose every window is here is greyed")
    func submenuGreyedWhenAllHere() {
        let core = seededCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(4), pid: 41, appName: "Safari")
            )
        )
        let rows = core.barMenuRows(.glyph([WindowID(1), WindowID(4)]))
        #expect(!rows[0].enabled)
        #expect(submenu(rows[0]).allSatisfy { !$0.enabled })
    }

    @Test("a group with one window left takes the plain rows")
    func goneMemberCollapses() {
        let core = seededCore()
        let rows = core.barMenuRows(.glyph([WindowID(2), WindowID(99)]))
        guard case .action = rows[0].kind else {
            Issue.record("expected a plain Move row")
            return
        }
        #expect(rows[1].title == "Float Window")
    }

    /// The render hands a collapsed group's windows to its item,
    /// which is what the item's menu names.
    @Test("an App Bar item carries its group's windows")
    func barItemCarriesItsGroup() {
        let core = seededCore()
        let item = core.barItem(
            for: [WindowID(2), WindowID(3)],
            style: AppBarLook()
        )
        #expect(item.members == [WindowID(2), WindowID(3)])
    }

    @Test("a window gone since the render offers only the shelf")
    func goneWindowOffersShelf() {
        let core = seededCore()
        let rows = core.barMenuRows(.appItem([WindowID(99)]))
        #expect(titles(rows) == shelf)
    }
}
