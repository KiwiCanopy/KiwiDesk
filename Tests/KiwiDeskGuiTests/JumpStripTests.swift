import AppKit
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiHub's app strip (#3135): All first, a tile narrowing the
/// list to its app's rows in the list's order; typing returns the
/// strip to All and dims the tiles with no match, which the strip
/// then skips; ← → move it only while the field is empty.
@Suite("KiwiHub app strip")
struct JumpStripTests {
    static func row(
        _ id: UInt32,
        pid: pid_t,
        _ app: String,
        _ title: String = "",
        hidden: Bool = false
    ) -> JumpEntry {
        JumpEntry(
            target: hidden ? .hiddenApp(pid) : .window(WindowID(id)),
            pid: pid,
            app: app,
            title: title,
            space: hidden ? nil : "1",
            spaceIcon: nil,
            status: .shown
        )
    }

    /// Mail's 2nd window is the one used before; Notes is the app
    /// used before that; Xcode lists no window.
    static var snapshot: JumpSnapshot {
        let entries = [
            row(1, pid: 10, "Mail", "Draft"),
            row(2, pid: 20, "Notes", "Ideas"),
            row(3, pid: 10, "Mail", "Inbox"),
            row(4, pid: 20, "Notes", "List"),
        ]
        return JumpSnapshot(
            entries: entries,
            here: "1",
            hereIcon: nil,
            apps: [
                JumpApp(pid: 20, name: "Notes"),
                JumpApp(pid: 10, name: "Mail"),
                JumpApp(pid: 30, name: "Xcode", bundleID: "com.apple.dt"),
            ]
        )
    }

    private func titles(_ list: JumpList) -> [String] {
        list.results.map(\.entry.title)
    }

    @Test("All is today's list; a tile narrows to its app in order")
    func tileNarrows() {
        var list = JumpList(snapshot: Self.snapshot)
        #expect(list.tile == 0 && list.stripApp == nil)
        #expect(titles(list) == ["Draft", "Ideas", "Inbox", "List"])
        list.pickTile(2)
        #expect(list.stripApp?.name == "Mail")
        #expect(titles(list) == ["Draft", "Inbox"])
        #expect(list.selection == 0)
        list.pickTile(0)
        #expect(titles(list).count == 4)
    }

    @Test("an app with no window shows no rows and nothing selected")
    func emptyApp() {
        var list = JumpList(snapshot: Self.snapshot)
        list.pickTile(3)
        #expect(list.results.isEmpty)
        #expect(list.selection == nil)
        #expect(list.stripApp?.bundleID == "com.apple.dt")
    }

    @Test("the last-app opener keeps row 1, the window used before")
    func lastApp() {
        var list = JumpList(snapshot: Self.snapshot)
        list.pickLastApp()
        #expect(list.stripApp?.name == "Mail")
        #expect(list.selected?.entry.title == "Draft")
    }

    @Test("typing returns to All and dims the apps with no match")
    func typingCoversAll() {
        var list = JumpList(snapshot: Self.snapshot)
        list.pickTile(1)
        list.setQuery("inbox")
        #expect(list.tile == 0)
        #expect(titles(list) == ["Inbox"])
        #expect(list.tileMatches(0))
        #expect(!list.tileMatches(1))
        #expect(list.tileMatches(2))
        #expect(!list.tileMatches(3))
    }

    @Test("a dimmed tile takes no pick and the strip skips it")
    func dimmedTilesAreSkipped() {
        var list = JumpList(snapshot: Self.snapshot)
        list.setQuery("inbox")
        list.pickTile(1)
        #expect(list.tile == 0)
        list.stepTile(1, wrap: true)
        #expect(list.stripApp?.name == "Mail")
        #expect(titles(list) == ["Inbox"])
        list.stepTile(1, wrap: true)
        #expect(list.tile == 0)
    }

    @Test("the strip wraps on a fresh press and stops on a held key")
    func wrapOnFreshPress() {
        var list = JumpList(snapshot: Self.snapshot)
        list.stepTile(-1, wrap: false)
        #expect(list.tile == 0)
        list.stepTile(-1, wrap: true)
        #expect(list.tile == 3)
    }

    @Test("a count is windows, never a hidden app's row")
    func windowCount() {
        let list = JumpList(snapshot: Self.snapshot)
        #expect(list.windowCount(of: JumpApp(pid: 10, name: "Mail")) == 2)
        let hidden = JumpList(
            snapshot: JumpSnapshot(
                entries: [Self.row(9, pid: 40, "Music", hidden: true)],
                here: "1",
                hereIcon: nil
            )
        )
        #expect(hidden.windowCount(of: JumpApp(pid: 40, name: "Music")) == 0)
    }

    @Test("← → walk the strip only while the field is empty")
    func arrows() {
        func key(_ code: UInt16, empty: Bool) -> JumpKey? {
            JumpKey.of(
                keyCode: code,
                modifiers: [],
                scope: .windows,
                naming: false,
                stripMoves: empty
            )
        }
        #expect(key(123, empty: true) == .side(-1))
        #expect(key(124, empty: true) == .side(1))
        #expect(key(123, empty: false) == nil)
        #expect(key(124, empty: false) == nil)
        let held = JumpKey.of(
            keyCode: 124,
            modifiers: .command,
            scope: .windows,
            naming: false,
            stripMoves: true
        )
        #expect(held != .side(1))
    }

    @Test("a snapshot with no strip of its own lists its rows' apps")
    func defaultApps() {
        let snapshot = JumpSnapshot(
            entries: Self.snapshot.entries,
            here: "1",
            hereIcon: nil
        )
        #expect(snapshot.apps.map(\.pid) == [10, 20])
    }
}
