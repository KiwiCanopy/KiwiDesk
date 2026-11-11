import Foundation
import Testing

@testable import KiwiDeskCore

/// The pickers' "Open apps" section reads every app KiwiDesk knows
/// is open, not only what the screen shows: a window on a hidden
/// Space and one on an away Desktop count, each app once, and
/// KiwiDesk itself never.
@Suite("Open apps reach every Space")
@MainActor
struct OpenAppsTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("open-apps-\(UUID().uuidString)")
        )
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        core.vision.listWindows = { [] }
        return core
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        pid: pid_t,
        app: String,
        bundle: String?,
        in space: SpaceID
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(id),
                pid: pid,
                appName: app,
                appBundleID: bundle
            )
        )
        core.state.workspaces.add(WindowID(id), to: space)
    }

    @Test("a hidden Space's and an away Desktop's apps are open")
    func reachesEverySpace() {
        let core = makeCore()
        track(
            core,
            1,
            pid: 900_101,
            app: "Safari",
            bundle: "com.apple.Safari",
            in: "1"
        )
        track(
            core,
            2,
            pid: 900_102,
            app: "qemu-system-aarch64",
            bundle: nil,
            in: "2"
        )
        core.state.awayWindows[WindowID(3)] = AwayWindow(
            id: WindowID(3),
            pid: 900_103,
            appName: "Notes",
            appBundleID: "com.apple.Notes",
            nativeSpace: 4
        )
        let keys = Set(core.openApps(beneathNormal: false).map(\.key))
        #expect(
            keys == [
                "com.apple.safari", "qemu-system-aarch64",
                "com.apple.notes",
            ]
        )
    }

    @Test("a pocketed window's app and a parked, unfiled one are open")
    func pocketAndParkedAway() {
        let core = makeCore()
        track(
            core,
            1,
            pid: 900_101,
            app: "Notes",
            bundle: "com.apple.Notes",
            in: "1"
        )
        #expect(core.state.markPocketWindow(WindowID(1)))
        core.state.pocketWindow(WindowID(1))
        #expect(core.state.workspaces.space(of: WindowID(1)) == nil)
        core.state.awayWindows[WindowID(2)] = AwayWindow(
            id: WindowID(2),
            pid: 900_102,
            appName: "",
            appBundleID: "com.apple.Mail",
            nativeSpace: 4,
            isUp: false
        )
        let apps = core.openApps(beneathNormal: false)
        #expect(apps.map(\.key) == ["com.apple.notes", "com.apple.mail"])
        #expect(apps.last?.name == "com.apple.mail")
    }

    @Test("an app listed and tracked is one row; KiwiDesk is none")
    func oneRowPerApp() {
        let core = makeCore()
        track(
            core,
            1,
            pid: 900_101,
            app: "Safari",
            bundle: "com.apple.Safari",
            in: "2"
        )
        track(
            core,
            2,
            pid: 900_101,
            app: "Safari",
            bundle: "com.apple.Safari",
            in: "1"
        )
        track(
            core,
            3,
            pid: getpid(),
            app: "KiwiDesk",
            bundle: "com.kiwicanopy.kiwidesk",
            in: "1"
        )
        core.eventLoop.processIdentity.note(
            RunningApp(
                pid: 900_101,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "com.apple.Safari", name: "Safari")
            )
        )
        core.vision.listWindows = {
            [
                FloatDetection.ListedWindow(
                    number: 70,
                    pid: 900_101,
                    layer: 0,
                    frame: CGRect(x: 0, y: 0, width: 90, height: 90),
                    owner: "Safari"
                )
            ]
        }
        let apps = core.openApps(beneathNormal: false)
        #expect(apps.map(\.key) == ["com.apple.safari"])
        #expect(apps.map(\.name) == ["Safari"])
    }
}
