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
    private func returns(_ core: KiwiCore, title: String = "") {
        var window = ManagedWindow(
            id: WindowID(5),
            pid: 100,
            appName: "Notes",
            appBundleID: "app.test.100"
        )
        window.title = title
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(5), to: "2")
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
        core.moveHiddenApp(100, into: "1", matching: "inbox")
        returns(core, title: "Drafts")
        core.payHiddenAppMove(focused: WindowID(5))
        #expect(core.state.workspaces.space(of: WindowID(5)) == "2")
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
        #expect(honored.upperBound <= pay.lowerBound)
        // Filed before the follow decides, or it switches away.
        #expect(pay.upperBound <= follow.lowerBound)
    }
}
