import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A new window its App Rule files into an unshown Space follows
/// with no launch owed (#2478), through the real `.windowCreated`
/// arm. Every refusal sits beside the paid case it differs from by
/// one input: not created while KiwiDesk watched, a young process
/// with no press, a press older than KiwiDesk, an unreadable age,
/// boot still running, another app's debt, a fresh Desktop switch.
/// The fixture is `LaunchFollowTests`' — a resident in Space 1, the
/// app ruled to Space 2 — with the create route live and boot done.
@Suite("A ruled new window follows with no launch owed (#2478)", .serialized)
@MainActor
struct LaunchFollowSpawnTests {
    typealias Base = LaunchFollowTests

    /// The process `processAge` seconds old, a press `pressAge`
    /// seconds ago, KiwiDesk watching for `watchedFor` seconds.
    static func makeCore(
        processAge: TimeInterval? = 3_600,
        pressAge: TimeInterval? = nil,
        watchedFor: TimeInterval = 600
    ) -> KiwiCore {
        let core = Base.makeCore(pressAge: pressAge)
        core.launchFollow.processAge = { _ in processAge }
        core.launchFollow.watchedFor = { watchedFor }
        core.windowCreates.isLive = true
        core.boot.reachedReady = true
        return core
    }

    /// WindowServer created `id` `ago` seconds before now.
    static func created(
        _ id: UInt32,
        on core: KiwiCore,
        ago: TimeInterval = 0.2
    ) {
        core.windowCreates.noteCreated(
            WindowID(id),
            at: core.wallClock().addingTimeInterval(-ago)
        )
    }

    static func expectFollowed(_ core: KiwiCore, window: UInt32 = 9) {
        #expect(core.state.workspaces.activeSpace == Base.ruled)
        #expect(
            core.state.workspaces[Base.ruled]?.focused
                == WindowID(window)
        )
        #expect(core.focusedWindowID == WindowID(window))
    }

    @Test("An old process's new window follows, as a full switch")
    func oldProcessSpawnFollows() {
        let core = Self.makeCore()
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Self.expectFollowed(core)
        #expect(core.deferred.task(for: .spaceSettle) != nil)
    }

    @Test("A window not created while KiwiDesk watched stays put")
    func adoptedWindowStays() {
        // A boot sweep, an unlock's heal, a re-track: no create.
        let core = Self.makeCore()
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("Without the WindowServer route nothing follows unowed")
    func deadRouteStays() async {
        let core = Self.makeCore()
        Self.created(9, on: core)
        core.windowCreates.isLive = false
        Base.arrive(9, on: core)
        Base.expectStayed(core)
        // Nor through a late create: the claim noted no slot.
        await LaunchFollowLateCreateTests.lateCreate(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A create older than the bound is no new window")
    func staleCreateStays() {
        let core = Self.makeCore()
        Self.created(9, on: core, ago: WindowCreateLedger.bound + 1)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A destroyed id is forgotten, so its reuse is not new")
    func destroyedIDStays() {
        let core = Self.makeCore()
        Self.created(9, on: core)
        core.windowCreates.noteDestroyed(WindowID(9))
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A young process's window with no press stays put")
    func youngProcessWithoutPressStays() {
        // The login restore (#2478 ▸ Ruling — login restore).
        let core = Self.makeCore(processAge: 5)
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A young process's window a press opened follows")
    func youngProcessWithPressFollows() {
        // ⌘N right after the launch.
        let core = Self.makeCore(processAge: 5, pressAge: 0.2)
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Self.expectFollowed(core)
    }

    @Test("A press older than KiwiDesk opened nothing")
    func pressBeforeKiwiDeskStays() {
        // The login password, read before KiwiDesk started.
        let core = Self.makeCore(
            processAge: 5,
            pressAge: 0.2,
            watchedFor: 0.1
        )
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A press past the grace opened nothing")
    func stalePressStays() {
        let core = Self.makeCore(
            processAge: 5,
            pressAge: LaunchFollowIntent.pressGrace + 0.5
        )
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("An unreadable process age counts as young")
    func unreadableAgeStays() {
        let core = Self.makeCore(processAge: nil)
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("The age bound is inclusive at the cold-start grace")
    func ageAtTheGraceFollows() {
        let core = Self.makeCore(
            processAge: LaunchFollowIntent.coldStartGrace
        )
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Self.expectFollowed(core)
    }

    @Test("Nothing follows unowed while boot still runs")
    func bootStays() {
        let core = Self.makeCore()
        core.boot.reachedReady = false
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("Nothing follows unowed inside a deferred sweep chunk")
    func deferredRetilesStay() {
        let core = Self.makeCore()
        core.defersEventRetiles = true
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        #expect(core.state.workspaces.activeSpace == Base.home)
    }

    @Test("Another app's standing launch debt holds the follow")
    func otherAppsDebtStands() {
        let core = Self.makeCore()
        core.oweLaunchFollow("app.other")
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
        #expect(core.launchFollow.owed() == "app.other")
    }

    @Test("A window just after a Desktop switch is the switch's")
    func desktopSwitchGraceStays() {
        let core = Self.makeCore()
        core.lastDesktopSwitch = Date()
        Self.created(9, on: core)
        Base.arrive(9, on: core)
        Base.expectStayed(core)
    }

    @Test("A transient overlay never follows unowed")
    func overlayStays() {
        let core = Self.makeCore()
        Self.created(8, on: core)
        Base.arrive(8, on: core, overlay: true)
        Base.expectStayed(core, window: 8)
    }
}
