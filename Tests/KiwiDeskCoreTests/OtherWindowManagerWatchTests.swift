import Foundation
import Testing

@testable import KiwiDeskCore

/// Another window manager beside KiwiDesk is stated once while it
/// runs, from the boot scan or a launch, and again as gone when its
/// last process exits (#1882).
@MainActor
@Suite("Other window manager detection (#1882)")
struct OtherWindowManagerWatchTests {
    private static let aerospace = "bobko.aerospace"

    private final class Log {
        var detected: [String] = []
        var gone: [String] = []
    }

    private func recording(_ watch: OtherWindowManagerWatch) -> Log {
        let log = Log()
        watch.onDetected = { log.detected.append($0.bundleID) }
        watch.onGone = { log.gone.append($0.bundleID) }
        return log
    }

    @Test("a running manager is stated once")
    func launchStatedOnce() {
        let watch = OtherWindowManagerWatch()
        let log = recording(watch)
        watch.noteLaunch(pid: 10, bundleID: Self.aerospace)
        watch.noteLaunch(pid: 11, bundleID: Self.aerospace)
        #expect(log.detected == [Self.aerospace])
    }

    @Test("an unknown app or a missing id states nothing")
    func unknownStatesNothing() {
        let watch = OtherWindowManagerWatch()
        let log = recording(watch)
        watch.noteLaunch(pid: 10, bundleID: "com.apple.Safari")
        watch.noteLaunch(pid: 11, bundleID: nil)
        #expect(log.detected.isEmpty)
    }

    @Test("the boot scan states each running manager, once")
    func scanStatesRunning() {
        let watch = OtherWindowManagerWatch()
        let log = recording(watch)
        watch.scanRunning([
            (1, "com.apple.finder"),
            (2, Self.aerospace),
            (3, "com.amethyst.amethyst"),
        ])
        watch.noteLaunch(pid: 4, bundleID: Self.aerospace)
        #expect(
            log.detected == [Self.aerospace, "com.amethyst.Amethyst"]
        )
    }

    @Test("the last exit states it gone, and a relaunch warns again")
    func lastExitStatesGone() {
        let watch = OtherWindowManagerWatch()
        let log = recording(watch)
        watch.noteLaunch(pid: 10, bundleID: Self.aerospace)
        watch.noteLaunch(pid: 11, bundleID: Self.aerospace)
        watch.noteExit(pid: 10)
        #expect(log.gone.isEmpty)
        watch.noteExit(pid: 99)
        watch.noteExit(pid: 11)
        #expect(log.gone == [Self.aerospace])
        watch.noteLaunch(pid: 12, bundleID: Self.aerospace)
        #expect(log.detected == [Self.aerospace, Self.aerospace])
    }

    @Test("quit asks every running process of that manager")
    func quitTerminatesItsProcesses() {
        let watch = OtherWindowManagerWatch()
        var asked: [pid_t] = []
        watch.terminate = { asked.append($0) }
        watch.noteLaunch(pid: 10, bundleID: Self.aerospace)
        watch.noteLaunch(pid: 11, bundleID: Self.aerospace)
        watch.noteLaunch(pid: 20, bundleID: "com.amethyst.Amethyst")
        watch.quit(OtherWindowManagerWatch.known[0])
        #expect(asked.sorted() == [10, 11])
    }

    @Test("launch and exit events reach the watch through the core")
    func eventsRoute() {
        let core = makeTestCore()
        let log = recording(core.otherWindowManagers)
        core.handle(
            .appLaunched(
                pid: 4242,
                name: "AeroSpace",
                bundleID: Self.aerospace
            )
        )
        core.handle(.appTerminated(pid: 4242))
        #expect(log.detected == [Self.aerospace])
        #expect(log.gone == [Self.aerospace])
    }

    @Test("every known bundle id is listed once")
    func knownIdsAreUnique() {
        let ids = OtherWindowManagerWatch.known.map {
            $0.bundleID.lowercased()
        }
        #expect(Set(ids).count == ids.count)
    }
}
