import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The one focus move a lens's quiet open owes (#3122 ▸ Ruling
/// amendment): to the first member window to arrive, through the
/// real `.windowCreated` arm, and never once the focus moved, a
/// click came or the lens went off. Each cancel sits beside the
/// paid case it differs from by one input.
@Suite("A lens's quiet open moves the focus once (#3122)", .serialized)
@MainActor
struct KiwiVisionAutoOpenFocusTests {
    typealias F = KiwiVisionAutoOpenTests

    /// The lens on with no member open: both apps owed.
    static func owing() -> KiwiCore {
        let (core, _) = F.makeCore()
        F.toggle(core)
        #expect(core.launchFollow.quietOpen != nil)
        return core
    }

    static func arrive(
        _ id: UInt32,
        bundleID: String,
        on core: KiwiCore,
        overlay: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 900_110 + Int32(id),
            appName: "Member",
            appBundleID: bundleID,
            frame: CGRect(x: 0, y: 30, width: 400, height: 300)
        )
        window.isTransientOverlay = overlay
        core.handle(.windowCreated(window))
    }

    @Test("the first member window to arrive takes the focus")
    func firstArrivalTakesFocus() {
        let core = Self.owing()
        Self.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(7))
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("a later arrival opens without taking the focus")
    func laterArrivalStays() {
        let core = Self.owing()
        Self.arrive(7, bundleID: F.music, on: core)
        core.focusWindow(WindowID(1), warp: false)
        Self.arrive(8, bundleID: F.notes, on: core)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("another app's window and an overlay leave the debt")
    func strangersLeaveTheDebt() {
        let core = Self.owing()
        Self.arrive(6, bundleID: "com.test.other", on: core)
        Self.arrive(7, bundleID: F.music, on: core, overlay: true)
        #expect(core.launchFollow.quietOpen != nil)
    }

    @Test("a focus change since the press cancels the move")
    func focusChangeCancels() {
        let core = Self.owing()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(2), pid: 900_120, appName: "B")
            )
        )
        core.focusWindow(WindowID(2), warp: false)
        Self.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(2))
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("a click since the press cancels the move")
    func clickCancels() {
        let core = Self.owing()
        core.lastLeftClick = (
            at: core.wallClock().addingTimeInterval(0.1),
            point: .zero,
            reached: nil
        )
        Self.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("the lens going off cancels the move")
    func lensOffCancels() {
        let core = Self.owing()
        core.setKiwiVision(.off)
        Self.arrive(7, bundleID: F.music, on: core)
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("another app coming forward retires it; its own does not")
    func activationRetires() {
        let core = Self.owing()
        core.noteAppActivation(
            AppActivation(pid: 900_150, bundleID: F.music, launchedAt: nil)
        )
        #expect(core.launchFollow.quietOpen != nil)
        core.noteAppActivation(
            AppActivation(
                pid: 900_151,
                bundleID: "com.test.here",
                launchedAt: nil
            )
        )
        #expect(core.launchFollow.quietOpen != nil)
        core.noteAppActivation(
            AppActivation(
                pid: 900_152,
                bundleID: "com.test.other",
                launchedAt: nil
            )
        )
        #expect(core.launchFollow.quietOpen == nil)
    }

    /// Past the bound the debt and the quiet mark are gone: the
    /// window arrives as any new window does.
    @Test("the debt ends at the launch follow's bound")
    func boundEnds() {
        let core = Self.owing()
        let late = core.wallClock().addingTimeInterval(
            LaunchFollowIntent.drainWindow + 1
        )
        #expect(core.launchFollow.opensQuietly(F.music, at: late) == false)
        core.wallClock = { late }
        Self.arrive(7, bundleID: F.music, on: core)
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("Open or Focus on a quiet app lifts its quiet mark")
    func namingTheAppLiftsTheMark() {
        let core = Self.owing()
        let now = core.wallClock()
        #expect(core.launchFollow.opensQuietly(F.music, at: now))
        core.oweLaunchFollow(F.music, at: now)
        #expect(!core.launchFollow.opensQuietly(F.music, at: now))
    }
}
