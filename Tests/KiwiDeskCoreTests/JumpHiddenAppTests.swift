import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Move here on a hidden app (#1513, #1875 ▸ Rulings): the unhide
/// brings the app's windows back into their own Spaces, and the one
/// it reports focused is filed into the Space the move was asked in.
@MainActor
@Suite("Move here on a hidden app (#1513)", .serialized)
struct JumpHiddenAppTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        core.openOrFocus.activate = { _ in }
        for space: SpaceID in ["1", "2"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return core
    }

    /// The unhide's re-track: the window returns to its own Space.
    private func returns(
        _ core: KiwiCore,
        title: String = "",
        to space: SpaceID = "2",
        fullscreen: Bool = false,
        sticky: StickyScope = .none
    ) {
        var window = ManagedWindow(
            id: WindowID(5),
            pid: 100,
            appName: "Notes",
            appBundleID: "app.test.100"
        )
        window.title = title
        window.isFullscreen = fullscreen
        window.stickyScope = sticky
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(5), to: space)
    }

    private func logging(_ core: KiwiCore) -> Lines {
        let lines = Lines()
        core.onLog = { lines.all.append($0) }
        return lines
    }

    private final class Lines {
        var all: [String] = []
        func contain(_ text: String) -> Bool {
            all.contains { $0.contains(text) }
        }
    }

    /// Owed at the frozen clock, reported two seconds later.
    private func oweThenReport(
        _ core: KiwiCore,
        pressAge: TimeInterval? = nil
    ) {
        core.moveHere(.hiddenApp(100))
        let later = core.wallClock().addingTimeInterval(2)
        core.wallClock = { later }
        core.launchFollow.pressAge = { pressAge }
    }

    @Test("the returning focused window is filed here")
    func paysHere() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "1")
        #expect(core.jump.owedApp == nil)
    }

    @Test("a title that does not match stays where it returned")
    func mismatchStays() {
        let core = makeCore()
        let lines = logging(core)
        core.moveHiddenApp(100, into: "1", matching: "inbox")
        returns(core, title: "Drafts")
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
        #expect(lines.contain("no title match"))
        // Logged, never drawn: the follow switches away from it.
        let cue = WindowActionRefusal.noTitleMatch(app: "", text: "")
        #expect(!lines.contain(cue.logReason))
    }

    @Test("a title that matches moves here")
    func matchMoves() {
        let core = makeCore()
        core.moveHiddenApp(100, into: "1", matching: "INBOX")
        returns(core, title: "Inbox — 3 new")
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "1")
    }

    @Test("a press since the move stands it down")
    func pressStandsDown() {
        let core = makeCore()
        oweThenReport(core, pressAge: 1)
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
        #expect(core.jump.owedApp == nil)
    }

    /// The control: the press that made the move is older.
    @Test("the press that made the move does not stand it down")
    func ownPressPays() {
        let core = makeCore()
        oweThenReport(core, pressAge: 3)
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "1")
    }

    @Test("a commanded focus since the move stands it down")
    func commandedStandsDown() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        core.eventLoop.lastCommandedFocus = .now
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
    }

    @Test("a full-screen window stays where it returned")
    func fullscreenStandsDown() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        returns(core, fullscreen: true)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
    }

    @Test("a window the sticky gate holds stays where it returned")
    func stickyStandsDown() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        returns(core, sticky: .global)
        #expect(core.stickyMoveBlock(WindowID(5), to: "1") != nil)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
    }

    @Test("a window already here owes nothing and moves nothing")
    func alreadyHere() {
        let core = makeCore()
        let lines = logging(core)
        core.moveHere(.hiddenApp(100))
        returns(core, to: "1")
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "1")
        #expect(lines.contain("move stood down"))
        #expect(core.jump.owedApp == nil)
    }

    @Test("the real focus report pays through the handler")
    func paysThroughTheHandler() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        returns(core)
        core.handle(.windowFocused(WindowID(5)))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.jump.owedApp == nil)
    }

    @Test("off the Space it was owed for, nothing moves")
    func standsDownOffSpace() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        core.state.workspaces.activate("2")
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
    }

    @Test("past the follow's bound, nothing moves")
    func standsDownPastTheBound() {
        let core = makeCore()
        core.moveHere(.hiddenApp(100))
        let late = core.wallClock().addingTimeInterval(
            FollowFocusIntent.drainWindow + 1
        )
        core.wallClock = { late }
        returns(core)
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
    }

    @Test("the honored focus report pays the debt")
    func reportWiring() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+FocusEvents.swift"
                ),
            encoding: .utf8
        )
        let honored = try #require(
            source.range(of: "rememberHonoredFocus(id)")
        )
        let pay = try #require(
            source.range(of: "payHiddenAppMove(focused: id)")
        )
        let follow = try #require(
            source.range(of: "scheduleFocusFollow(id)")
        )
        // Paid first, so the #1207 memory files the Space it holds.
        #expect(pay.upperBound <= honored.lowerBound)
        // Filed before the follow decides, or it switches away.
        #expect(pay.upperBound <= follow.lowerBound)
    }
}
