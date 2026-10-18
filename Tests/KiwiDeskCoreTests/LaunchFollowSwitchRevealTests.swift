import Foundation
import Testing

@testable import KiwiDeskCore

/// **A window a Desktop switch's batch reveals claims no launch
/// follow** (#2347, #1599): the switch handler forgets every debt
/// owed before it, and one owed in the batch's gap must not be
/// paid by a window the switch, not the press, brought back. Driven
/// through `LaunchFollowTests`' fixture, with the fold's own flag
/// stated, beside the control that differs by that flag alone.
@Suite("A switch reveal claims no launch follow (#2347)", .serialized)
@MainActor
struct LaunchFollowSwitchRevealTests {
    @Test("an arrival inside the batch's fold stays put")
    func revealDoesNotClaim() {
        let core = LaunchFollowTests.makeCore()
        LaunchFollowTests.activate(core)
        core.eventLoop.switchReads.applying = true
        LaunchFollowTests.arrive(9, on: core)
        core.eventLoop.switchReads.applying = false
        LaunchFollowTests.expectStayed(core)
        #expect(
            core.launchFollow.owed() == LaunchFollowTests.bundle,
            "the debt was spent"
        )
    }

    @Test("the same arrival outside a fold follows")
    func arrivalOutsideAFoldFollows() {
        let core = LaunchFollowTests.makeCore()
        LaunchFollowTests.activate(core)
        LaunchFollowTests.arrive(9, on: core)
        #expect(
            core.state.workspaces.activeSpace == LaunchFollowTests.ruled
        )
    }
}
