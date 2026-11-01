import Foundation
import Testing

@testable import KiwiDeskCore

/// The Pocket key's claim through the arrival door (#2612 ▸ 7,
/// #2629): it beats the App Rule, takes only a window WindowServer
/// reported created (or any where the route is absent), waits for
/// a create still due, and the tie ends with the app's row.
@Suite("pocket_app's claim and tie", .serialized)
@MainActor
struct PocketAppKeyTests {
    typealias Fixture = PocketAppFixture
    private let mine = WindowID(9)

    @Test("the claim skips the app's Open in a Space")
    func claimBeatsTheAppRule() {
        let fixture = Fixture(appRule: SpaceID("2"))
        fixture.core.state.workspaces.ensureSpace(SpaceID("2"))
        fixture.press()
        fixture.arrive(9)
        let workspaces = fixture.core.state.workspaces
        #expect(workspaces.space(of: mine) == workspaces.activeSpace)
        #expect(fixture.owner(of: mine) == Fixture.app)
    }

    @Test("a window WindowServer reported created is claimed at once")
    func createdIsClaimed() {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.core.windowServerChanged(.created, id: mine)
        fixture.arrive(9)
        #expect(fixture.owner(of: mine) == Fixture.app)
    }

    @Test("a candidate keeps its rule, earns no follow, and comes out")
    func candidateKeepsItsRule() async throws {
        let fixture = Fixture(appRule: SpaceID("2"))
        fixture.core.state.workspaces.ensureSpace(SpaceID("2"))
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.core.oweLaunchFollow(Fixture.app)
        fixture.arrive(9)
        let active = fixture.core.state.workspaces.activeSpace
        #expect(fixture.core.state.workspaces.space(of: mine) == SpaceID("2"))
        #expect(active != SpaceID("2"))
        // Its create lands: it comes out where the user is.
        fixture.core.windowServerChanged(.created, id: mine)
        await fixture.core.deferred.task(for: .arrivalCreated)?.value
        let window = try #require(fixture.core.state.windows[mine])
        #expect(fixture.core.state.renderSpace(of: window) == active)
        #expect(window.isFloating)
        #expect(fixture.core.state.workspaces.activeSpace == active)
    }

    @Test("a window the boot adopts is never claimed")
    func bootAdoptionIsNotClaimed() {
        let fixture = Fixture()
        fixture.press()
        fixture.core.eventLoop.bootScan.stepBudget = .seconds(1)
        fixture.arrive(9)
        fixture.core.eventLoop.bootScan.stepBudget = nil
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.claim != nil)
    }

    @Test("a create still due is claimed when it lands")
    func lateCreateIsClaimed() async {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.arrive(9)
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.claim?.candidate == mine)
        fixture.core.windowServerChanged(.created, id: mine)
        let hop = fixture.core.deferred.task(for: .arrivalCreated)
        #expect(hop != nil)
        await hop?.value
        #expect(fixture.owner(of: mine) == Fixture.app)
    }

    @Test("no create in the bound frees the claim for the real window")
    func expiredCandidateKeepsTheClaim() {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.arrive(9)
        let arrived = fixture.core.wallClock()
        fixture.core.wallClock = {
            arrived.addingTimeInterval(
                LaunchFollowIntent.lateCreateBound
            )
        }
        fixture.core.resolveExpiredArrivals()
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.claim != nil)
        #expect(fixture.claim?.candidate == nil)
    }

    @Test("a created window outranks a candidate still waiting")
    func createdWindowTakesOver() {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.arrive(9)
        #expect(fixture.claim?.candidate == mine)
        fixture.core.windowServerChanged(.created, id: WindowID(10))
        fixture.arrive(10)
        #expect(fixture.owner(of: WindowID(10)) == Fixture.app)
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
    }

    @Test("spending the claim retires its app's launch debt")
    func claimRetiresTheLaunchDebt() {
        let fixture = Fixture()
        fixture.press()
        fixture.core.oweLaunchFollow(Fixture.app)
        fixture.arrive(9)
        #expect(fixture.core.launchFollow.owed() == nil)
    }

    @Test("the app's activation after the spend owes no follow")
    func activationAfterTheSpend() {
        let fixture = Fixture()
        fixture.core.launchFollow.pressAge = { 0.2 }
        fixture.press()
        fixture.arrive(9)
        let now = fixture.core.wallClock()
        fixture.core.noteAppActivation(
            AppActivation(
                pid: Fixture.pid,
                bundleID: Fixture.app,
                launchedAt: now.addingTimeInterval(-0.3)
            ),
            now: now
        )
        #expect(fixture.core.launchFollow.owed(at: now) == nil)
    }

    @Test("removing the row makes the window an ordinary one")
    func rowRemovalUnties() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.press()
        #expect(fixture.core.state.isPocketed(mine))
        fixture.installRow(false)
        let workspaces = fixture.core.state.workspaces
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(workspaces.space(of: mine) == workspaces.activeSpace)
        #expect(fixture.core.state.windows[mine]?.isFloating == false)
    }

    @Test("closing the window frees the key; the next press opens anew")
    func closeFreesTheKey() {
        let fixture = Fixture()
        fixture.press()
        fixture.arrive(9)
        fixture.core.eventLoop.onEvent(
            .windowDestroyed(mine, wasMinimized: false)
        )
        #expect(fixture.core.state.pocket.isEmpty)
        fixture.press()
        #expect(fixture.opened.count == 2)
    }

    @Test("the row's stored Lua is the ruled shape")
    func storedShape() {
        #expect(
            PocketAppLuaArg.call("Com.Mitchellh.Ghostty")
                == #"KiwiDesk.pocket_app("com.mitchellh.ghostty")"#
        )
        #expect(
            PocketAppLuaArg.bundleID(
                of: #"KiwiDesk.pocket_app("com.x.y")"#
            ) == "com.x.y"
        )
        #expect(
            PocketAppLuaArg.bundleID(of: "KiwiDesk.pocket_app('x')")
                == nil
        )
    }
}
