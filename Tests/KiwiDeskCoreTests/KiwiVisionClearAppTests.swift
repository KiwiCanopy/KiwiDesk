import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's "The current app's other windows" switch (#2103
/// rulings 17–21): stored app-wide as `kiwivision.clear_app`, a verb
/// a session value, and each window of the focused app — its process
/// or a sibling of it — a hole in the mask for its visible part.
@Suite("KiwiVision clear app")
@MainActor
struct KiwiVisionClearAppTests {
    private let focused = WindowID(1)
    private let sameApp = WindowID(2)
    private let otherApp = WindowID(3)
    private let samePid: pid_t = 900_001
    private let otherPid: pid_t = 900_002

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-app-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        let windows: [(WindowID, pid_t)] = [
            (focused, samePid), (sameApp, samePid), (otherApp, otherPid),
        ]
        for (id, pid) in windows {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: pid, appName: "App\(pid)")
                )
            )
        }
        let space = core.state.workspaces.space(of: focused)!
        core.state.workspaces.focus(focused, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        core.vision.listWindows = { [] }
        return core
    }

    private func clearIDs(_ core: KiwiCore) -> [Bool] {
        core.visionMaskWindows(
            target: focused.raw,
            targetPid: samePid,
            refreshingList: true
        )
        .map(\.clear)
    }

    @Test("gui.json stores clear_app; its absence reads off")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.visionClearApp = true
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["kiwivision"] as? [String: Any])
        #expect(group["clear_app"] as? Bool == true)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.visionClearApp == true)
        #expect(AppWideSettings().visionClearApp == false)
    }

    @Test("the verb is a session value and masks on its own")
    func verbMasks() throws {
        let core = makeCore()
        try core.guiConfigStore.save(GuiConfig())
        #expect(
            core.execute("kiwivision.set_clear_app", args: [.bool(true)])
                .isSuccess
        )
        #expect(core.appWide.visionClearApp)
        #expect(core.guiConfigStore.load()?.appWide == nil)
        core.vision.isOn = true
        #expect(core.visionMasks, "the app switch masks without Wallpaper")
        let request = core.visionRequest()
        #expect(!request.clearWallpaper, "the wallpaper stays hazed")
        #expect(request.windows.contains { $0.clear })
    }

    /// The members run in state order: the same app's window is a
    /// hole, another app's stays hazed; off, nothing is clear.
    @Test("the focused app's other windows are holes")
    func sameAppIsClear() {
        let core = makeCore()
        #expect(clearIDs(core) == [false, false])
        core.setAppWide(persisting: false) { $0.visionClearApp = true }
        #expect(clearIDs(core) == [true, false])
    }

    /// Another app's listed window from the same process family
    /// clears too; one of a stranger stays hazed.
    @Test("listed windows take the verdict by their process")
    func listedWindowsByProcess() {
        let core = makeCore()
        core.setAppWide(persisting: false) { $0.visionClearApp = true }
        let frame = CGRect(x: 600, y: 40, width: 100, height: 100)
        core.vision.listWindows = {
            [
                FloatDetection.ListedWindow(
                    number: 50,
                    pid: self.samePid,
                    layer: 0,
                    frame: frame
                ),
                FloatDetection.ListedWindow(
                    number: 51,
                    pid: 900_003,
                    layer: 0,
                    frame: frame
                ),
            ]
        }
        let windows = core.visionMaskWindows(
            target: focused.raw,
            targetPid: samePid,
            refreshingList: true
        )
        #expect(windows.map(\.clear) == [true, false, true, false])
    }

    /// An app running as two processes (#1785): the child filed as
    /// unlisted under the target's bundle is the same app, read from
    /// what attach filed, never LaunchServices.
    @Test("a sibling process's window is clear")
    func siblingProcessIsClear() {
        let core = makeCore()
        core.setAppWide(persisting: false) { $0.visionClearApp = true }
        let child: pid_t = 900_004
        let bundle = AppRef(bundleID: "test.kiwi.profiles", name: "P")
        core.eventLoop.processIdentity.note(
            RunningApp(pid: samePid, activationPolicy: .regular, ref: bundle)
        )
        core.eventLoop.processIdentity.record(
            RunningApp(pid: child, activationPolicy: .regular, ref: bundle)
        )
        var lookups: [pid_t] = []
        core.eventLoop.processIdentity.appAt = { pid in
            lookups.append(pid)
            return nil
        }
        #expect(
            core.visionClearPids(
                target: child,
                among: [samePid, child, otherPid]
            ) == [samePid, child]
        )
        #expect(lookups.isEmpty, "the pass asks LaunchServices nothing")
    }

    /// An own key window is the target — a dialog — and its app is
    /// this one: the tiled Settings window, tracked under this
    /// process, stays clear.
    @Test("an own key window's app is KiwiDesk")
    func ownKeyWindowNamesThisProcess() {
        let core = makeCore()
        let settings = WindowID(4)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: settings, pid: getpid(), appName: "Kiwi")
            )
        )
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 777_777, isDialog: true)
        }
        core.setAppWide(persisting: false) { $0.visionClearApp = true }
        core.vision.isOn = true
        let windows = core.visionRequest().windows
        #expect(windows.filter(\.clear).count == 1)
        #expect(windows.count == 4, "the focus is behind the dialog")
    }
}
