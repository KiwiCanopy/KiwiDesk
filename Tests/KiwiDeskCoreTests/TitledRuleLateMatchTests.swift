import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A titled Space rule's one late match (#3341): a new window whose
/// title matched no rule at its creation is filed by the first title
/// report that matches one, through the real handler, and never once
/// the user pressed, the settle bound passed, or the user filed it.
@Suite("A titled rule files a late title once (#3341)", .serialized)
@MainActor
struct TitledRuleLateMatchTests {
    private let brave = "com.brave.browser"
    private let ruled = SpaceID("3")
    private let late = WindowID(900_101)

    /// Space 1 shown with a focused resident of another app, Space 3
    /// a titled rule's, and no bare rule for the app.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kd-titled-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let start = Date(timeIntervalSince1970: 1_000_000)
        core.wallClock = { start }
        core.state.workspaces.ensureSpace(ruled)
        core.state.titledAppRules = TitledSpaceRules([
            "\(brave):Work": ruled
        ])
        core.handle(.windowCreated(resident()))
        return core
    }

    private func resident() -> ManagedWindow {
        ManagedWindow(
            id: WindowID(900_100),
            pid: 900_100,
            appName: "Other",
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    private func browser(title: String) -> ManagedWindow {
        ManagedWindow(
            id: late,
            pid: 900_101,
            appName: "Brave Browser",
            appBundleID: brave,
            title: title,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    /// Opens the browser window, then hands the focus back to the
    /// resident, as a window an app opens in the background leaves
    /// it: a window that holds the focus is never filed late.
    private func open(_ core: KiwiCore, title: String) {
        core.handle(.windowCreated(browser(title: title)))
        core.state.workspaces.focus(WindowID(900_100), in: SpaceID("1"))
    }

    private func space(_ core: KiwiCore) -> SpaceID? {
        core.state.workspaces.space(of: late)
    }

    @Test("the first matching title files the window in the rule's Space")
    func lateTitleFiles() {
        let core = makeCore()
        open(core, title: "")
        #expect(space(core) == SpaceID("1"))
        #expect(core.state.titledRulePending[late] != nil)
        core.handle(.windowTitleChanged(late, "Untitled - Brave"))
        #expect(space(core) == SpaceID("1"))
        core.handle(.windowTitleChanged(late, "Inbox - Brave – Work"))
        #expect(space(core) == ruled)
        #expect(core.state.titledRulePending[late] == nil)
        #expect(core.state.workspaces.lastFocused != late)
    }

    @Test("it files once: a later match moves nothing")
    func filesOnce() {
        let core = makeCore()
        open(core, title: "")
        core.handle(.windowTitleChanged(late, "a – Work"))
        #expect(space(core) == ruled)
        core.fileMembership(late, into: SpaceID("1"), from: ruled)
        core.handle(.windowTitleChanged(late, "b – Work"))
        #expect(space(core) == SpaceID("1"))
    }

    @Test("a press since the arrival stands the match down")
    func pressStandsDown() {
        let core = makeCore()
        open(core, title: "")
        let later = core.wallClock().addingTimeInterval(2)
        core.wallClock = { later }
        core.launchFollow.pressAge = { 1 }
        core.handle(.windowTitleChanged(late, "a – Work"))
        #expect(space(core) == SpaceID("1"))
        #expect(core.state.titledRulePending[late] == nil)
    }

    @Test("past the title settle the match stands down")
    func boundStandsDown() {
        let core = makeCore()
        open(core, title: "")
        let after = core.wallClock().addingTimeInterval(
            CrossSessionMatch.titleSettle + 1
        )
        core.wallClock = { after }
        core.handle(.windowTitleChanged(late, "a – Work"))
        #expect(space(core) == SpaceID("1"))
    }

    @Test("a user filing ends the record")
    func userFilingEnds() {
        let core = makeCore()
        open(core, title: "")
        core.state.stampUserFiling(late)
        #expect(core.state.titledRulePending[late] == nil)
    }

    @Test("a window matched at creation owes no late match")
    func matchedAtCreationOwesNothing() {
        let core = makeCore()
        core.handle(.windowCreated(browser(title: "a – Work")))
        #expect(space(core) == ruled)
        #expect(core.state.titledRulePending[late] == nil)
    }

    @Test("the focused window is never filed late")
    func focusedStandsDown() {
        let core = makeCore()
        core.handle(.windowCreated(browser(title: "")))
        core.state.workspaces.focus(late, in: SpaceID("1"))
        core.handle(.windowTitleChanged(late, "a – Work"))
        #expect(space(core) == SpaceID("1"))
    }

    @Test("a destroy ends the record")
    func destroyEnds() {
        let core = makeCore()
        open(core, title: "")
        core.handle(.windowDestroyed(late, wasMinimized: false))
        #expect(core.state.titledRulePending[late] == nil)
    }
}
