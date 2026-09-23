import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Who retires the launch follow and who keeps it (#1599):
/// another app's activation retires it, press or not; the owing
/// app's own activation keeps it; a Desktop switch retires it and
/// an activation inside one owes nothing; Open or Focus owes it
/// through the door whatever the press timing. The fixture is
/// `LaunchFollowTests`'.
@Suite("The launch follow's retires and door (#1599)", .serialized)
@MainActor
struct LaunchFollowRetireTests {
    private typealias F = LaunchFollowTests

    @Test("Another app's activation retires the debt, press or not")
    func otherAppActivationRetires() {
        for press in [0.2, 15.0] {
            let core = F.makeCore()
            F.activate(core)
            core.launchFollow.pressAge = { press }
            F.activate(core, bundleID: "app.other")
            F.arrive(9, on: core)
            F.expectStayed(core)
        }
    }

    @Test("The owing app's own activation keeps the debt")
    func ownActivationKeeps() {
        // Open or Focus from the CLI: no press, and the app's own
        // activation follows the command.
        let core = F.makeCore(pressAge: nil)
        core.oweLaunchFollow(F.bundle, at: F.ahead)
        F.activate(core)
        F.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == F.ruled)
    }

    @Test("Another app's ruled window does not claim the debt")
    func otherAppDoesNotClaim() {
        let core = F.makeCore()
        core.state.appRules["app.other"] = F.ruled
        F.activate(core)
        F.arrive(8, on: core, bundleID: "app.other")
        F.expectStayed(core, window: 8)
        F.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == F.ruled)
    }

    @Test("An activation inside a Desktop switch owes nothing")
    func activationWithADesktopSwitchStays() {
        let core = F.makeCore()
        core.lastDesktopSwitch = F.ahead
        F.activate(core)
        F.arrive(9, on: core)
        F.expectStayed(core)
    }

    @Test("A Desktop switch after the activation retires the debt")
    func desktopSwitchRetires() {
        let core = F.makeCore()
        F.activate(core)
        #expect(core.launchFollow.owed() == F.bundle)
        core.handleDesktopChange()
        #expect(core.launchFollow.owed() == nil)
    }

    @Test("Open or Focus owes the follow for a launch and a pull")
    func launchVerbOwes() {
        // Not running: the launch branch.
        let launched = F.makeCore(pressAge: nil)
        launched.openOrFocus.openApp = { _, _ in true }
        #expect(
            launched.execute(
                "pull_or_spawn",
                args: [.string(F.bundle)]
            ).isSuccess
        )
        #expect(launched.launchFollow.owed() == F.bundle)
        // Running with nothing up: the activate branch.
        let pulled = F.makeCore(pressAge: nil)
        pulled.openOrFocus.runningAppPID = { _ in 7 }
        pulled.openOrFocus.activate = { _ in }
        #expect(
            pulled.execute(
                "pull_or_spawn",
                args: [.string(F.bundle)]
            ).isSuccess
        )
        #expect(pulled.launchFollow.owed() == F.bundle)
    }
}
