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
        #expect(fixture.core.state.pocketKeyOwner(of: mine) == Fixture.app)
    }

    @Test("a window the boot adopts is never claimed")
    func bootAdoptionIsNotClaimed() {
        let fixture = Fixture()
        fixture.press()
        fixture.core.eventLoop.bootScan.stepBudget = .seconds(1)
        fixture.arrive(9)
        fixture.core.eventLoop.bootScan.stepBudget = nil
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.core.arrivals.pocketClaim != nil)
    }

    @Test("a create still due is claimed when it lands")
    func lateCreateIsClaimed() async {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.arrive(9)
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.core.arrivals.pocketClaim?.candidate == mine)
        fixture.core.windowServerChanged(.created, id: mine)
        let hop = fixture.core.deferred.task(for: .arrivalCreated)
        #expect(hop != nil)
        await hop?.value
        #expect(fixture.core.state.pocketKeyOwner(of: mine) == Fixture.app)
    }

    @Test("no create in the bound frees the claim for the real window")
    func expiredCandidateKeepsTheClaim() {
        let fixture = Fixture()
        fixture.core.windowCreates.isLive = true
        fixture.press()
        fixture.arrive(9)
        let arrived = fixture.core.wallClock()
        fixture.core.wallClock = {
            arrived.addingTimeInterval(LaunchFollowIntent.lateCreateBound)
        }
        fixture.core.resolveExpiredArrivals()
        #expect(fixture.core.state.pocketPhase(of: mine) == nil)
        #expect(fixture.core.arrivals.pocketClaim != nil)
        #expect(fixture.core.arrivals.pocketClaim?.candidate == nil)
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
