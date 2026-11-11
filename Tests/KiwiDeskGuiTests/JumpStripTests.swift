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
                JumpApp(pid: 30, name: "Xcode"),
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
        #expect(list.stripApp?.name == "Xcode")
    }

    @Test("the last-app opener keeps row 1, the window used before")
    func lastApp() {
        var list = JumpList(snapshot: Self.snapshot)
        list.pickLastApp()
        #expect(list.stripApp?.name == "Mail")
        #expect(list.selected?.entry.title == "Draft")
    }

    /// A lens orders its apps' rows first, so row 1 need not be the
    /// window used last: the opener takes Core's `lastUsed`.
    @Test("the last-app opener lands on Core's last-used window")
    func lastUsedOutranksRowOne() {
        let base = Self.snapshot
        var list = JumpList(
            snapshot: JumpSnapshot(
                entries: base.entries,
                here: "1",
                hereIcon: nil,
                apps: base.apps,
                lastUsed: .window(WindowID(4))
            )
        )
        list.pickLastApp()
        #expect(list.stripApp?.name == "Notes")
        #expect(list.selected?.entry.title == "List")
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

    /// The field never takes ← →: queries are short, so the strip
    /// keeps them typed or not (#3135 ▸ Amendment).
    @Test("← → walk the strip on Windows, a held ⌘ excepted")
    func arrows() {
        func key(
            _ code: UInt16,
            _ modifiers: NSEvent.ModifierFlags = []
        ) -> JumpKey? {
            JumpKey.of(
                keyCode: code,
                modifiers: modifiers,
                scope: .windows,
                naming: false
            )
        }
        #expect(key(123) == .side(-1))
        #expect(key(124) == .side(1))
        #expect(key(124, .shift) == .side(1))
        #expect(key(124, .command) != .side(1))
        var keys = KiwiHubKeys()
        keys.left = "control+b"
        keys.right = "control+f"
        // b and f on the US layout: Lua's alternatives move too.
        let alternative = JumpKey.of(
            keyCode: 11,
            modifiers: .control,
            scope: .windows,
            naming: false,
            keys: keys
        )
        #expect(alternative == .side(-1))
    }

    /// Back is the opener's own chord with ⇧, whatever it is bound
    /// to; ⌥⇥ itself reaches the panel only as the global hotkey
    /// (#3135, owner 2026-11-09).
    @Test("the opener's chord with ⇧ steps back, a fixed one never")
    func backFollowsTheOpener() {
        func key(
            _ modifiers: NSEvent.ModifierFlags,
            back: KeyCombo?,
            _ scope: JumpScope = .windows
        ) -> JumpKey? {
            JumpKey.of(
                keyCode: 48,
                modifiers: modifiers,
                scope: scope,
                naming: false,
                back: back
            )
        }
        let optionTab = JumpKey.back(of: KeyCombo.parse("option+tab"))
        let controlTab = JumpKey.back(of: KeyCombo.parse("control+tab"))
        #expect(optionTab == KeyCombo.parse("shift+option+tab"))
        #expect(key([.option, .shift], back: optionTab) == .side(-1))
        #expect(key([.control, .shift], back: controlTab) == .side(-1))
        // Rebound to ⌃⇥, ⇧⌥⇥ is no back key any more.
        #expect(key([.option, .shift], back: controlTab) == .swallow)
        #expect(key(.option, back: optionTab) == .swallow)
        #expect(key([.option, .shift], back: optionTab, .view) == .swallow)
        #expect(key(.shift, back: optionTab) == .stepScope(forward: false))
    }

    @Test("no back key for no opener, a ⇧ chord, a bare ⇥ or a tap")
    func noBackForm() {
        #expect(JumpKey.back(of: nil) == nil)
        #expect(JumpKey.back(of: KeyCombo.parse("shift+control+y")) == nil)
        #expect(JumpKey.back(of: KeyCombo.parse("tab")) == nil)
        #expect(JumpKey.back(of: KeyCombo.parse("cmd+cmd")) == nil)
        #expect(
            JumpKey.back(of: KeyCombo.parse("control+option+y"))
                == KeyCombo.parse("shift+control+option+y")
        )
    }

    @Test("the last-app opener steps where Windows shows")
    @MainActor
    func openerSteps() {
        #expect(JumpPanelController.lastAppAction(showing: nil) == .open)
        #expect(
            JumpPanelController.lastAppAction(showing: .windows) == .step
        )
        #expect(
            JumpPanelController.lastAppAction(showing: .view)
                == .switchScope
        )
    }

    @Test("a query's strip steps over the apps with no match")
    func typedStepSkipsDimmed() {
        var list = JumpList(snapshot: Self.snapshot)
        list.setQuery("inbox")
        // Notes (tile 1) holds no match: the step lands on Mail.
        list.stepTile(1, wrap: true)
        #expect(list.tile == 2)
        #expect(list.query == "inbox")
        #expect(list.results.map(\.entry.title) == ["Inbox"])
        list.stepTile(-1, wrap: true)
        #expect(list.tile == 0)
        list.stepTile(-1, wrap: true)
        #expect(list.tile == 2)
    }

    @Test("an empty field's strip walks every tile")
    func emptyStepWalksAll() {
        var list = JumpList(snapshot: Self.snapshot)
        var seen: [Int] = []
        for _ in 0..<list.tileCount {
            list.stepTile(1, wrap: true)
            seen.append(list.tile)
        }
        #expect(seen == [1, 2, 3, 0])
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
