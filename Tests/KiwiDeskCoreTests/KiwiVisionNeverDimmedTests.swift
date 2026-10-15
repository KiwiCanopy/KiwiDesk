import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's Never dimmed list (#2103 ruling 26): stored app-wide
/// as `kiwivision.never_dimmed`, an entry a bundle id or — for a
/// process without one, SketchyBar's case — its process name; each
/// listed app's windows are holes in the mask, beneath the normal
/// layer as well, down to the desktop icons.
@Suite("KiwiVision never dimmed")
@MainActor
struct KiwiVisionNeverDimmedTests {
    private let focused = WindowID(1)
    private let bundled: pid_t = 900_011
    private let bare: pid_t = 900_012
    private let stranger: pid_t = 900_013

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-never-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: focused, pid: 900_010, appName: "Front")
            )
        )
        let space = core.state.workspaces.space(of: focused)!
        core.state.workspaces.focus(focused, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        core.eventLoop.processIdentity.note(
            RunningApp(
                pid: bundled,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "Test.Kiwi.Music", name: "Music")
            )
        )
        let frame = CGRect(x: 500, y: 40, width: 90, height: 90)
        let desktop = KiwiCore.desktopIconLayer
        core.vision.listWindows = {
            [
                FloatDetection.ListedWindow(
                    number: 70,
                    pid: self.bundled,
                    layer: 0,
                    frame: frame,
                    owner: "Music"
                ),
                FloatDetection.ListedWindow(
                    number: 71,
                    pid: self.stranger,
                    layer: 0,
                    frame: frame,
                    owner: "Other"
                ),
                FloatDetection.ListedWindow(
                    number: 72,
                    pid: self.bare,
                    layer: -20,
                    frame: frame,
                    owner: "sketchybar"
                ),
                FloatDetection.ListedWindow(
                    number: 73,
                    pid: self.stranger,
                    layer: -20,
                    frame: frame,
                    owner: "Other"
                ),
                FloatDetection.ListedWindow(
                    number: 74,
                    pid: self.bare,
                    layer: desktop,
                    frame: frame,
                    owner: "sketchybar"
                ),
            ]
        }
        return core
    }

    @Test("gui.json stores never_dimmed, trimmed and lowercased")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.visionNeverDimmed = ["sketchybar"]
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["kiwivision"] as? [String: Any])
        #expect(group["never_dimmed"] as? [String] == ["sketchybar"])
        #expect(
            AppWideSettings.neverDimmedEntries([
                " SketchyBar ", "com.Apple.Music", "", "sketchybar",
            ]) == ["sketchybar", "com.apple.music"]
        )
        #expect(AppWideSettings().visionNeverDimmed.isEmpty)
    }

    @Test("the verb takes a table or words, and nothing clears it")
    func verbShapes() {
        let core = makeCore()
        let table = core.execute(
            "kiwivision.set_never_dimmed",
            args: [.array([.string("sketchybar"), .string("Com.X")])]
        )
        #expect(table.isSuccess)
        #expect(core.appWide.visionNeverDimmed == ["sketchybar", "com.x"])
        #expect(
            core.execute(
                "kiwivision.set_never_dimmed",
                args: [.string("a"), .string("b")]
            ).isSuccess
        )
        #expect(core.appWide.visionNeverDimmed == ["a", "b"])
        #expect(
            !core.execute(
                "kiwivision.set_never_dimmed",
                args: [.array([.bool(true)])]
            ).isSuccess
        )
        #expect(
            core.execute("kiwivision.set_never_dimmed", args: []).isSuccess
        )
        #expect(core.appWide.visionNeverDimmed.isEmpty)
    }

    /// A bundled app by its bundle id, a bare process by its name —
    /// beneath the normal layer too, never at the desktop icons' —
    /// and a stranger's lower window left out of the mask.
    @Test("listed apps are holes, beneath the normal layer too")
    func neverDimmedAreHoles() {
        let core = makeCore()
        core.setAppWide(persisting: false) {
            $0.visionNeverDimmed = ["test.kiwi.music", "sketchybar"]
        }
        core.vision.isOn = true
        #expect(core.visionMasks, "the list masks on its own")
        let windows = core.visionMaskWindows(
            target: focused.raw,
            targetPid: 900_010,
            refreshingList: true
        )
        #expect(windows.map(\.clear) == [true, false, true])
        core.setAppWide(persisting: false) { $0.visionNeverDimmed = [] }
        #expect(!core.visionMasks)
    }

    @Test("on screen now lists each app once, beneath the layer too")
    func appsOnScreen() {
        let core = makeCore()
        let apps = core.appsOnScreen()
        #expect(apps.map(\.key) == ["test.kiwi.music", "other", "sketchybar"])
        #expect(apps.map(\.name) == ["Music", "Other", "sketchybar"])
        #expect(apps.first?.bundleID == "test.kiwi.music")
        #expect(apps.last?.bundleID == nil)
    }
}
