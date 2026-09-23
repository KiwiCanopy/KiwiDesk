import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Opening an app follows its window into the Space its app rule
/// files it in (#1599), through the real activation entry, fold
/// and `.windowCreated` arm. Every refusal sits beside the paid
/// case it differs from by one input: a background spawn (no
/// activation), a login restore (no press), a Desktop switch, a
/// remembered Space, the rule naming the Space you are in, an
/// overlay, another app, a later activation.
@Suite("A launch follows its app rule's window (#1599)", .serialized)
@MainActor
struct LaunchFollowTests {
    private static let bundle = "app.launched"
    private static let pid: pid_t = 7
    private static let ruled = SpaceID("2")
    private static let home = SpaceID("1")

    /// A resident focused in Space 1, the app ruled to Space 2,
    /// and a press 0.2 s ago unless the case says otherwise.
    private func makeCore(pressAge: TimeInterval? = 0.2) -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-launch-follow-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "Here")
            )
        )
        core.state.workspaces.ensureSpace(Self.ruled)
        core.state.appRules[Self.bundle] = Self.ruled
        core.launchFollow.pressAge = { pressAge }
        #expect(core.state.workspaces.activeSpace == Self.home)
        return core
    }

    private func arrive(
        _ id: UInt32,
        on core: KiwiCore,
        pid: pid_t = LaunchFollowTests.pid,
        bundleID: String? = LaunchFollowTests.bundle
    ) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid,
                    appName: "Launched",
                    appBundleID: bundleID,
                    frame: CGRect(x: 0, y: 0, width: 400, height: 300)
                )
            )
        )
    }

    private func expectStayed(_ core: KiwiCore, window: UInt32 = 9) {
        #expect(
            core.state.workspaces.space(of: WindowID(window))
                == Self.ruled
        )
        #expect(core.state.workspaces.activeSpace == Self.home)
    }

    @Test("A press-caused activation follows the ruled window there")
    func pressedLaunchFollows() {
        let core = makeCore()
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
        #expect(core.state.workspaces[Self.ruled]?.focused == WindowID(9))
        #expect(core.focusedWindowID == WindowID(9))
    }

    @Test("A window spawned with no activation stays put")
    func backgroundSpawnStays() {
        let core = makeCore()
        arrive(9, on: core)
        expectStayed(core)
    }

    @Test("An activation no press caused owes nothing")
    func pressLessActivationStays() {
        // The login restore: its activation came 15 s after the
        // password; and no press read at all is the unit default.
        for age in [15.0, nil] as [TimeInterval?] {
            let core = makeCore(pressAge: age)
            core.noteAppActivation(Self.pid)
            arrive(9, on: core)
            expectStayed(core)
        }
    }

    @Test("The press bound is inclusive at the grace")
    func pressAtTheGraceFollows() {
        let core = makeCore(pressAge: LaunchFollowIntent.pressGrace)
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("An activation inside a Desktop switch owes nothing")
    func activationWithADesktopSwitchStays() {
        let core = makeCore()
        core.lastDesktopSwitch = Date()
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        expectStayed(core)
    }

    @Test("A Desktop switch after the activation retires the debt")
    func desktopSwitchRetires() {
        let core = makeCore()
        core.noteAppActivation(Self.pid)
        #expect(core.launchFollow.owed() == Self.pid)
        core.handleDesktopChange()
        #expect(core.launchFollow.owed() == nil)
    }

    @Test("Another app's activation replaces the debt")
    func laterActivationReplaces() {
        let core = makeCore()
        core.noteAppActivation(Self.pid)
        core.noteAppActivation(99)
        arrive(9, on: core)
        expectStayed(core)
    }

    @Test("Another app's ruled window does not claim the debt")
    func otherAppDoesNotClaim() {
        let core = makeCore()
        core.state.appRules["app.other"] = Self.ruled
        core.noteAppActivation(Self.pid)
        arrive(8, on: core, pid: 8, bundleID: "app.other")
        expectStayed(core, window: 8)
        // …and the owing app's own window still follows after it.
        arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("A window with a remembered Space is no launch")
    func rememberedSpaceStays() {
        let core = makeCore()
        let elsewhere = SpaceID("3")
        core.state.workspaces.ensureSpace(elsewhere)
        core.state.rememberedSpaces[WindowID(9)] = .restored(elsewhere)
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        #expect(core.state.workspaces.space(of: WindowID(9)) == elsewhere)
        #expect(core.state.workspaces.activeSpace == Self.home)
        // Unspent: the next ruled window of the app still follows.
        #expect(core.launchFollow.owed() == Self.pid)
    }

    @Test("A rule naming the Space you are in switches nothing")
    func ruleIntoActiveSpaceIsNoFollow() {
        let core = makeCore()
        core.state.appRules[Self.bundle] = Self.home
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        #expect(core.state.workspaces.space(of: WindowID(9)) == Self.home)
        #expect(core.launchFollow.owed() == Self.pid)
    }

    @Test("A transient overlay never spends the follow")
    func overlayDoesNotClaim() {
        let core = makeCore()
        core.noteAppActivation(Self.pid)
        var splash = ManagedWindow(
            id: WindowID(8),
            pid: Self.pid,
            appName: "Launched",
            appBundleID: Self.bundle,
            frame: CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        splash.isTransientOverlay = true
        core.handle(.windowCreated(splash))
        expectStayed(core, window: 8)
        arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("The follow is paid once")
    func paidOnce() {
        let core = makeCore()
        core.noteAppActivation(Self.pid)
        arrive(9, on: core)
        #expect(core.launchFollow.owed() == nil)
        _ = core.execute("focus_space", args: [.string(Self.home.raw)])
        #expect(core.state.workspaces.activeSpace == Self.home)
        arrive(10, on: core)
        expectStayed(core, window: 10)
    }
}
