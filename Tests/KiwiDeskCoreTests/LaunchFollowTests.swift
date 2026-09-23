import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Opening an app follows its window into the Space its app rule
/// files it in (#1599), through the real activation entry, fold
/// and `.windowCreated` arm. Every refusal sits beside the paid
/// case it differs from by one input: no activation (a background
/// spawn), no press (a login restore), an old process (a switch
/// to a running app), a remembered Space, the rule naming the
/// Space you are in, an overlay. The retires and the Open or
/// Focus door are `LaunchFollowRetireTests`'.
///
/// The activation is stamped AHEAD of the wall clock the arrival
/// claims on (tests.md, #1456), so no runner stall can age it.
@Suite("A launch follows its app rule's window (#1599)", .serialized)
@MainActor
struct LaunchFollowTests {
    static let bundle = "app.launched"
    static let ruled = SpaceID("2")
    static let home = SpaceID("1")

    /// A resident focused in Space 1, the app ruled to Space 2,
    /// and a press 0.2 s before the activation unless the case
    /// says otherwise.
    static func makeCore(pressAge: TimeInterval? = 0.2) -> KiwiCore {
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
        core.state.workspaces.ensureSpace(ruled)
        core.state.appRules[bundle] = ruled
        core.launchFollow.pressAge = { pressAge }
        #expect(core.state.workspaces.activeSpace == home)
        return core
    }

    /// The activation's own clock, read fresh and ahead of every
    /// later read — a stored one ages across a full run.
    static var ahead: Date {
        Date().addingTimeInterval(LaunchFollowIntent.drainWindow / 2)
    }

    /// An activation of `bundleID`, whose process started
    /// `launchedAgo` seconds before it.
    static func activate(
        _ core: KiwiCore,
        bundleID: String = bundle,
        launchedAgo: TimeInterval = 0.3,
        at clock: Date? = nil
    ) {
        // One reading: two would drift apart at the inclusive edge.
        let now = clock ?? ahead
        core.noteAppActivation(
            AppActivation(
                pid: 7,
                bundleID: bundleID,
                launchedAt: now.addingTimeInterval(-launchedAgo)
            ),
            now: now
        )
    }

    static func arrive(
        _ id: UInt32,
        on core: KiwiCore,
        bundleID: String = bundle,
        overlay: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 7,
            appName: "Launched",
            appBundleID: bundleID,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        window.isTransientOverlay = overlay
        core.handle(.windowCreated(window))
    }

    static func expectStayed(_ core: KiwiCore, window: UInt32 = 9) {
        #expect(
            core.state.workspaces.space(of: WindowID(window)) == ruled
        )
        #expect(core.state.workspaces.activeSpace == home)
    }

    @Test("A launch follows the ruled window there, as a full switch")
    func launchFollows() {
        let core = Self.makeCore()
        Self.activate(core)
        Self.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
        #expect(core.state.workspaces[Self.ruled]?.focused == WindowID(9))
        #expect(core.focusedWindowID == WindowID(9))
        // The switch's settle is armed — `followSwitch`, not a
        // bare hand-off with no native switch behind it.
        #expect(core.deferred.task(for: .spaceSettle) != nil)
    }

    @Test("A window spawned with no activation stays put")
    func backgroundSpawnStays() {
        let core = Self.makeCore()
        Self.arrive(9, on: core)
        Self.expectStayed(core)
    }

    @Test("An activation no press caused owes nothing")
    func pressLessActivationStays() {
        // The login restore: its activation came 15 s after the
        // password; and no press read at all is the unit default.
        for age in [15.0, nil] as [TimeInterval?] {
            let core = Self.makeCore(pressAge: age)
            Self.activate(core)
            Self.arrive(9, on: core)
            Self.expectStayed(core)
        }
    }

    @Test("The press bound is inclusive at the grace")
    func pressAtTheGraceFollows() {
        let core = Self.makeCore(
            pressAge: LaunchFollowIntent.pressGrace
        )
        Self.activate(core)
        Self.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("A running app already showing a window is no open")
    func runningAppActivationStays() {
        // A switch into an app, or its own call window: the process
        // is older than the launch grace AND shows a window.
        let core = Self.makeCore()
        Self.arrive(5, on: core, bundleID: "app.unruled")
        Self.activate(core, launchedAgo: 3_600)
        Self.arrive(9, on: core)
        Self.expectStayed(core)
    }

    @Test("The launch bound is inclusive at the grace")
    func launchAtTheGraceFollows() {
        let core = Self.makeCore()
        Self.activate(core, launchedAgo: LaunchFollowIntent.launchGrace)
        Self.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("A window remembered in the ruled Space is no launch")
    func rememberedInTheRuledSpaceStays() {
        // The rule's own Space, so only the fold's gate — never the
        // payer's space re-check — can refuse it.
        let core = Self.makeCore()
        core.state.rememberedSpaces[WindowID(9)] = .restored(Self.ruled)
        Self.activate(core)
        Self.arrive(9, on: core)
        Self.expectStayed(core)
        // Unspent: the next ruled window of the app still follows.
        #expect(core.launchFollow.owed() == Self.bundle)
    }

    @Test("A rule naming the Space you are in switches nothing")
    func ruleIntoActiveSpaceIsNoFollow() {
        let core = Self.makeCore()
        core.state.appRules[Self.bundle] = Self.home
        Self.activate(core)
        Self.arrive(9, on: core)
        #expect(core.state.workspaces.space(of: WindowID(9)) == Self.home)
        #expect(core.launchFollow.owed() == Self.bundle)
    }

    @Test("A transient overlay never spends the follow")
    func overlayDoesNotClaim() {
        let core = Self.makeCore()
        Self.activate(core)
        Self.arrive(8, on: core, overlay: true)
        Self.expectStayed(core, window: 8)
        Self.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Self.ruled)
    }

    @Test("The follow is paid once")
    func paidOnce() {
        let core = Self.makeCore()
        Self.activate(core)
        Self.arrive(9, on: core)
        #expect(core.launchFollow.owed() == nil)
        _ = core.execute("focus_space", args: [.string(Self.home.raw)])
        #expect(core.state.workspaces.activeSpace == Self.home)
        Self.arrive(10, on: core)
        Self.expectStayed(core, window: 10)
    }
}
