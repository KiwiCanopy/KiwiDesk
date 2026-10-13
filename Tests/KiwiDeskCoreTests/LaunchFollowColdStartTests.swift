import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A slow cold start follows too (#2201): the press that launched
/// the app counts when it came at most `pressGrace` before the
/// process STARTED, however late the app activates. The shapes are
/// the device's (2026-10-13, after a purge): Xcode activated 1.39 s
/// after the Spotlight Return, Word 7.75 s, each process starting
/// within 0.21 s of it; Xcode relaunching itself after an install
/// started 5.18 s after the last press. The fixture is
/// `LaunchFollowTests`'.
@Suite("A slow cold launch follows (#2201)", .serialized)
@MainActor
struct LaunchFollowColdStartTests {
    private typealias F = LaunchFollowTests

    /// A core whose last press is `pressAge` old, KiwiDesk having
    /// managed windows for `watched` seconds.
    private static func makeCore(
        pressAge: TimeInterval,
        watched: TimeInterval? = 60
    ) -> KiwiCore {
        let core = F.makeCore(pressAge: pressAge)
        core.launchFollow.watchedFor = { watched }
        return core
    }

    /// Activates and lands the ruled window.
    private static func launch(
        _ core: KiwiCore,
        launchedAgo: TimeInterval
    ) {
        F.activate(core, launchedAgo: launchedAgo)
        F.arrive(9, on: core)
    }

    @Test(
        "A press just before the process started follows",
        arguments: [(1.39, 1.18), (7.75, 7.58), (3.70, 3.57)]
    )
    func coldStartFollows(press: Double, launched: Double) {
        let core = Self.makeCore(pressAge: press)
        Self.launch(core, launchedAgo: launched)
        #expect(core.state.workspaces.activeSpace == F.ruled)
        #expect(core.focusedWindowID == WindowID(9))
    }

    @Test("The lead bound is inclusive at the press grace")
    func leadAtTheGraceFollows() {
        let core = Self.makeCore(pressAge: 6)
        Self.launch(
            core,
            launchedAgo: 6 - LaunchFollowIntent.pressGrace
        )
        #expect(core.state.workspaces.activeSpace == F.ruled)
    }

    @Test("A lead just past the press grace stays put")
    func leadPastTheGraceStays() {
        let core = Self.makeCore(pressAge: 6)
        Self.launch(
            core,
            launchedAgo: 6 - LaunchFollowIntent.pressGrace - 0.05
        )
        F.expectStayed(core)
    }

    @Test("The cold-start bound is inclusive, and past it stays put")
    func coldStartBound() {
        let grace = LaunchFollowIntent.coldStartGrace
        let at = Self.makeCore(pressAge: grace + 0.2)
        Self.launch(at, launchedAgo: grace)
        #expect(at.state.workspaces.activeSpace == F.ruled)
        let past = Self.makeCore(pressAge: grace + 0.3)
        Self.launch(past, launchedAgo: grace + 0.1)
        F.expectStayed(past)
    }

    @Test("A process started long after the press stays put")
    func selfRelaunchStays() {
        // Xcode relaunching itself after its install prompt.
        let core = Self.makeCore(pressAge: 5.64)
        Self.launch(core, launchedAgo: 0.46)
        F.expectStayed(core)
    }

    @Test("A press after the process started is no launch")
    func pressAfterStartStays() {
        let core = Self.makeCore(pressAge: 2)
        Self.launch(core, launchedAgo: 3)
        F.expectStayed(core)
    }

    @Test("A press from before KiwiDesk watched opens nothing")
    func pressBeforeWatchingStays() {
        // The login password: the restored apps start right after
        // it, and KiwiDesk itself starts later still.
        let core = Self.makeCore(pressAge: 7.75, watched: 5)
        Self.launch(core, launchedAgo: 7.58)
        F.expectStayed(core)
    }

    @Test("Unwired, the launch-keyed press is inert")
    func unwiredStays() {
        let core = Self.makeCore(pressAge: 7.75, watched: nil)
        Self.launch(core, launchedAgo: 7.58)
        F.expectStayed(core)
    }

    @Test("A Desktop switch around a cold launch still owes nothing")
    func desktopSwitchStillStays() {
        let core = Self.makeCore(pressAge: 7.75)
        core.lastDesktopSwitch = F.ahead
        Self.launch(core, launchedAgo: 7.58)
        F.expectStayed(core)
    }
}
