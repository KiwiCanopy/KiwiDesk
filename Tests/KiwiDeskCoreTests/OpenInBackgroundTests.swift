import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `open_in_background` (#3141 ▸ Ruling): it opens an app through
/// the one launcher's background mode only where the app has no
/// window, and its window arrives taking no focus. The hand-back's
/// two doors are `OpenInBackgroundHoldTests`'.
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
        #expect(core.launchFollow.holds.opened[Self.app] != nil)
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
        "an app with a window up or parked opens nothing",
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
        #expect(core.launchFollow.holds.opened.isEmpty)
    }

    @Test("an id LaunchServices cannot resolve is refused")
    func unknownAppRefused() {
        let (core, _) = Self.makeCore(found: false)
        let answer = Self.open(core)
        #expect(answer.error == "app not found: \(Self.app)")
        #expect(core.launchFollow.holds.opened.isEmpty)
    }

    @Test("its window arrives without taking the focus")
    func arrivalTakesNoFocus() {
        let core = Self.taken()
        #expect(core.focusedWindowID == WindowID(1))
        #expect(core.state.windows[WindowID(7)] != nil)
    }

    /// A lens's focus move and a hold live in separate slots.
    @Test("an open leaves a lens's owed focus move standing")
    func lensDebtSurvives() {
        let core = KiwiVisionAutoOpenFocusTests.owing()
        #expect(Self.open(core, Self.other).isSuccess)
        #expect(core.launchFollow.quietOpen != nil)
        #expect(core.launchFollow.holds.opened[Self.other] != nil)
    }

    @Test("Open or Focus on the app lifts its hold alone")
    func namingTheAppLiftsItsHold() {
        let core = Self.taken()
        #expect(Self.open(core, Self.other).isSuccess)
        core.oweLaunchFollow(Self.app, at: core.wallClock())
        #expect(Array(core.launchFollow.holds.opened.keys) == [Self.other])
    }
}
