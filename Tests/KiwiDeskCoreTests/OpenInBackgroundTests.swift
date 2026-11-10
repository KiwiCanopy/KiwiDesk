import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `open_in_background` (#3141 ▸ Ruling): it opens an app through
/// the one launcher's background mode only where the app has no
/// window, its window arrives taking no focus, and an app that
/// takes the focus anyway gives it back once per app, through the
/// real `.windowFocused` arm. Each let-out sits beside the paid
/// case it differs from by one input.
@Suite("open_in_background opens an app quietly (#3141)", .serialized)
@MainActor
struct OpenInBackgroundTests {
    static let app = "com.test.background"
    static let other = "com.test.other"

    final class Recorder {
        var opened: [(String, OpenAppMode)] = []
        var activated: [pid_t] = []
    }

    /// A focused w1 of another app; `running` answers a pid and
    /// `visible` its census.
    static func makeCore(
        running: Bool = false,
        visible: Int = 0,
        minimized: [UInt32] = [],
        found: Bool = true
    ) -> (KiwiCore, Recorder) {
        let core = makeTestCore(
            configDirectory: testTemporaryDirectory.appendingPathComponent(
                "kiwi-open-background-\(UUID().uuidString)"
            )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in running ? 4_242 : nil }
        core.openOrFocus.census = { _ in
            KiwiCore.AppWindowCensus(
                visible: visible,
                minimized: minimized.map { WindowID($0) }
            )
        }
        core.openOrFocus.openApp = { id, mode in
            recorder.opened.append((id, mode))
            return found
        }
        core.openOrFocus.activate = { recorder.activated.append($0) }
        arrive(1, bundleID: "com.test.here", on: core)
        core.focusWindow(WindowID(1), warp: false)
        return (core, recorder)
    }

    static func arrive(_ id: UInt32, bundleID: String, on core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: 900_300 + Int32(id),
                    appName: "App \(id)",
                    appBundleID: bundleID,
                    frame: CGRect(x: 0, y: 30, width: 400, height: 300)
                )
            )
        )
    }

    @discardableResult
    static func open(
        _ core: KiwiCore,
        _ bundleID: String = app
    ) -> CommandResponse {
        core.execute("open_in_background", args: [.string(bundleID)])
    }

    /// The app opened, its window up, and the app taking the focus.
    static func taken() -> KiwiCore {
        let (core, _) = makeCore()
        #expect(open(core).isSuccess)
        arrive(7, bundleID: app, on: core)
        return core
    }

    @Test("an app not running opens in the background, never activated")
    func launchesInBackground() {
        let (core, recorder) = Self.makeCore()
        #expect(Self.open(core).isSuccess)
        #expect(recorder.opened.map(\.0) == [Self.app])
        #expect(recorder.opened.map(\.1) == [.background])
        #expect(recorder.activated.isEmpty)
        #expect(core.launchFollow.quietOpen?.purpose == .hold)
        #expect(core.launchFollow.owed(at: core.wallClock()) == nil)
    }

    @Test("a running app with no window is reopened in the background")
    func reopensInBackground() {
        let (core, recorder) = Self.makeCore(running: true)
        #expect(Self.open(core).isSuccess)
        #expect(recorder.opened.map(\.1) == [.background])
        #expect(recorder.activated.isEmpty)
    }

    @Test(
        "an app with a window up, parked or tracked opens nothing",
        arguments: [(1, [UInt32]()), (0, [UInt32(5)])]
    )
    func windowUpOpensNothing(visible: Int, minimized: [UInt32]) {
        let (core, recorder) = Self.makeCore(
            running: true,
            visible: visible,
            minimized: minimized
        )
        #expect(Self.open(core).isSuccess)
        #expect(recorder.opened.isEmpty)
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("a tracked window of the app opens nothing")
    func trackedWindowOpensNothing() {
        let (core, recorder) = Self.makeCore()
        Self.arrive(7, bundleID: Self.app, on: core)
        #expect(Self.open(core).isSuccess)
        #expect(recorder.opened.isEmpty)
    }

    @Test("an id LaunchServices cannot resolve is refused")
    func unknownAppRefused() {
        let (core, _) = Self.makeCore(found: false)
        let answer = Self.open(core)
        #expect(answer.error == "app not found: \(Self.app)")
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("its window arrives without taking the focus")
    func arrivalTakesNoFocus() {
        let core = Self.taken()
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.state.windows[WindowID(7)] != nil)
    }

    @Test("the app taking the focus is handed back once, then kept")
    func takeHandedBackOnce() {
        let core = Self.taken()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(
            log.contains(
                "open_in_background: w7 took the focus — handed back to w1"
            )
        )
        #expect(core.launchFollow.quietOpen == nil)
        // A second take is the app's.
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
    }

    @Test("a click on the app's window keeps the focus there")
    func clickKeeps() {
        let core = Self.taken()
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(7))
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
        #expect(core.launchFollow.quietOpen == nil)
    }

    /// The user working on in their own app spends nothing.
    @Test("a click in the user's own window leaves the hold standing")
    func ownClickLeavesHold() {
        let core = Self.taken()
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(1))
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
    }

    @Test("past the grace the take is kept")
    func lateTakeKept() {
        let core = Self.taken()
        let late = core.wallClock().addingTimeInterval(
            LaunchFollowIntent.holdGrace + 1
        )
        core.wallClock = { late }
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(7))
        #expect(core.launchFollow.quietOpen == nil)
    }

    /// Another app's activation retires a lens's debt, never a hold.
    @Test("the user switching apps leaves the hold standing")
    func otherActivationLeavesHold() {
        let core = Self.taken()
        core.noteAppActivation(
            AppActivation(pid: 900_500, bundleID: Self.other, launchedAt: nil),
            now: core.wallClock()
        )
        #expect(core.launchFollow.quietOpen?.purpose == .hold)
    }

    @Test("two opens in a row each hand the focus back")
    func runOfOpensJoins() {
        let core = Self.taken()
        #expect(Self.open(core, Self.other).isSuccess)
        #expect(
            core.launchFollow.quietOpen?.bundleIDs == [Self.app, Self.other]
        )
        Self.arrive(8, bundleID: Self.other, on: core)
        core.handle(.windowFocused(WindowID(7)))
        #expect(core.focusedWindowID == WindowID(1))
        core.handle(.windowFocused(WindowID(8)))
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.launchFollow.quietOpen == nil)
    }

    @Test("Open or Focus on the app lifts its hold alone")
    func namingTheAppLiftsItsHold() {
        let core = Self.taken()
        #expect(Self.open(core, Self.other).isSuccess)
        core.oweLaunchFollow(Self.app, at: core.wallClock())
        #expect(core.launchFollow.quietOpen?.bundleIDs == [Self.other])
    }
}
