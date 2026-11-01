import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The unowed follow's LATE create (#2478): WindowServer's create
/// trailing the window's AX arrival (8–10 ms on TextEdit's ⌘N) pays
/// the follow on a later main-actor turn, outside the event-port
/// drain, while every stand-down still holds. Split from
/// `LaunchFollowSpawnTests` under §2.1, on its fixture.
@Suite("A late create pays the unowed follow (#2478)", .serialized)
@MainActor
struct LaunchFollowLateCreateTests {
    typealias Base = LaunchFollowTests
    typealias Spawn = LaunchFollowSpawnTests

    /// WindowServer's create for `id`, and the hop its payment
    /// takes out of the event-port drain: read before the await,
    /// since the payment's own run clears it (tests.md).
    static func lateCreate(_ id: UInt32, on core: KiwiCore) async {
        core.windowServerChanged(.created, id: WindowID(id))
        await core.deferred.task(for: .arrivalCreated)?.value
    }

    @Test("A create landing after the arrival pays the follow then")
    func lateCreateFollows() async {
        // TextEdit's ⌘N: the create trails the AX arrival by ~10 ms.
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        Base.expectStayed(core)
        core.windowServerChanged(.created, id: WindowID(9))
        // Not inside the drain: the payment waits for its hop.
        Base.expectStayed(core)
        let hop = core.deferred.task(for: .arrivalCreated)
        #expect(hop != nil)
        await hop?.value
        Spawn.expectFollowed(core)
    }

    @Test("A create past the late bound pays nothing")
    func lateCreatePastTheBoundStays() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        let arrived = core.wallClock()
        core.wallClock = {
            arrived.addingTimeInterval(
                LaunchFollowIntent.lateCreateBound + 0.1
            )
        }
        await Self.lateCreate(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A late create for another window pays nothing")
    func lateCreateOfAnotherWindowStays() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        await Self.lateCreate(10, on: core)
        Base.expectStayed(core)
        // The slot is still 9's, so its own create pays.
        await Self.lateCreate(9, on: core)
        Spawn.expectFollowed(core)
    }

    @Test("A window moved out of its rule's Space is not followed")
    func movedWindowStays() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        core.state.workspaces.remove(WindowID(9))
        core.state.workspaces.add(
            WindowID(9),
            to: Base.home,
            placement: .afterFocused
        )
        await Self.lateCreate(9, on: core)
        #expect(core.state.workspaces.activeSpace == Base.home)
    }

    @Test("A refused arrival leaves no late create to pay")
    func refusedArrivalOwesNoLateCreate() async {
        let core = Spawn.makeCore(processAge: 5)
        Base.arrive(9, on: core)
        #expect(core.launchFollow.spawn == nil)
        await Self.lateCreate(9, on: core)
        Base.expectStayed(core)
    }

    @Test("The spawning app's own activation keeps the late create")
    func ownActivationKeepsTheSpawn() async {
        // A notification click: the app activates between its
        // window's arrival and that window's create.
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        Base.activate(core, launchedAgo: 3_600)
        await Self.lateCreate(9, on: core)
        Spawn.expectFollowed(core)
    }

    @Test("Another app's activation retires the late create")
    func otherActivationRetiresTheSpawn() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        Base.activate(core, bundleID: "app.other", launchedAgo: 3_600)
        await Self.lateCreate(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A launch debt owed before the create holds the payment")
    func debtAtPaymentStands() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        core.oweLaunchFollow("app.other")
        await Self.lateCreate(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A Space the user left before the create is not pulled back")
    func userMovedOnStands() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        let elsewhere = SpaceID("3")
        core.state.workspaces.ensureSpace(elsewhere)
        core.state.workspaces.activate(elsewhere)
        await Self.lateCreate(9, on: core)
        #expect(core.state.workspaces.activeSpace == elsewhere)
    }

    @Test("A stop drops the late create")
    func stopDropsTheSpawn() {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        #expect(core.launchFollow.spawn != nil)
        core.stop()
        #expect(core.launchFollow.spawn == nil)
    }

    @Test("A route lost before the create pays nothing")
    func routeLostBeforeTheCreateStays() async {
        let core = Spawn.makeCore()
        Base.arrive(9, on: core)
        #expect(core.launchFollow.spawn != nil)
        core.windowCreates.isLive = false
        await Self.lateCreate(9, on: core)
        Base.expectStayed(core)
    }
}
