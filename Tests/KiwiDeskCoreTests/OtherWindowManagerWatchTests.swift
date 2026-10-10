import Foundation
import Testing

@testable import KiwiDeskCore

/// Another window manager beside KiwiDesk is stated once per
/// manager per session, from the boot scan or a launch (#1882).
@MainActor
@Suite("Other window manager detection (#1882)")
struct OtherWindowManagerWatchTests {
    private static let aerospace = "bobko.aerospace"

    private func recording(
        _ watch: OtherWindowManagerWatch
    ) -> () -> [String] {
        var seen: [String] = []
        watch.onDetected = { seen.append($0.bundleID) }
        return { seen }
    }

    @Test("a known manager's launch is stated once")
    func launchStatedOnce() {
        let watch = OtherWindowManagerWatch()
        let seen = recording(watch)
        watch.noteLaunch(bundleID: Self.aerospace)
        watch.noteLaunch(bundleID: Self.aerospace)
        #expect(seen() == [Self.aerospace])
    }

    @Test("an unknown app or a missing id states nothing")
    func unknownStatesNothing() {
        let watch = OtherWindowManagerWatch()
        let seen = recording(watch)
        watch.noteLaunch(bundleID: "com.apple.Safari")
        watch.noteLaunch(bundleID: nil)
        #expect(seen().isEmpty)
    }

    @Test("the boot scan states each running manager, once")
    func scanStatesRunning() {
        let watch = OtherWindowManagerWatch()
        let seen = recording(watch)
        watch.runningBundleIDs = {
            ["com.apple.finder", Self.aerospace, "com.amethyst.Amethyst"]
        }
        watch.scanRunning()
        watch.noteLaunch(bundleID: Self.aerospace)
        #expect(seen() == [Self.aerospace, "com.amethyst.Amethyst"])
    }

    @Test("a launch event reaches the watch through the core")
    func launchEventRoutes() {
        let core = makeTestCore()
        let seen = recording(core.otherWindowManagers)
        core.handle(
            .appLaunched(
                pid: 4242,
                name: "AeroSpace",
                bundleID: Self.aerospace
            )
        )
        #expect(seen() == [Self.aerospace])
    }

    @Test("every known bundle id is listed once")
    func knownIdsAreUnique() {
        let ids = OtherWindowManagerWatch.known.map(\.bundleID)
        #expect(Set(ids).count == ids.count)
    }
}
