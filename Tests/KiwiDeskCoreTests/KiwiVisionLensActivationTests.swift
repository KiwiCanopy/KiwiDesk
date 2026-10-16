import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Turning a KiwiVision lens on (#2103 v3, rulings 11, 23, 32, 37,
/// 40): one value says what KiwiVision draws, a named toggle turns
/// a lens on and the active lens's own toggle turns KiwiVision off,
/// a lens's look overrides the plain one through the one door, and
/// its member apps' windows stay clear — all of them, or the ones
/// whose title matches.
@Suite("KiwiVision lens activation")
@MainActor
struct KiwiVisionLensActivationTests {
    private let focused = WindowID(1)
    private let noteDraft = WindowID(2)
    private let noteOther = WindowID(3)
    private let notes: pid_t = 900_021
    private let music: pid_t = 900_022
    private let stranger: pid_t = 900_023

    private func makeCore(
        _ system: KiwiVisionAppearanceTests.FakeSystem? = nil
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-lens-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        if let system { core.vision.appearanceSwitch = system.machine }
        core.eventLoop.ownKeyWindow = { nil }
        for (id, pid, title) in [
            (focused, pid_t(900_020), "Front"),
            (noteDraft, notes, "Draft: plan"),
            (noteOther, notes, "Archive"),
        ] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: pid,
                        appName: "App",
                        appBundleID: pid == notes ? "test.kiwi.notes" : nil,
                        title: title
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: focused)!
        core.state.workspaces.focus(focused, in: space)
        core.eventLoop.processIdentity.note(
            RunningApp(
                pid: music,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "Test.Kiwi.Music", name: "Music")
            )
        )
        let frame = CGRect(x: 500, y: 40, width: 90, height: 90)
        core.vision.listWindows = {
            [
                FloatDetection.ListedWindow(
                    number: 70,
                    pid: self.music,
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
            ]
        }
        return core
    }

    private func define(_ core: KiwiCore, _ lens: [String: JSONValue]) {
        #expect(
            core.execute("kiwivision.define_lens", args: [.object(lens)])
                .isSuccess
        )
    }

    private func toggle(_ core: KiwiCore, _ name: String? = nil)
        -> CommandResponse
    {
        core.execute(
            "kiwivision.toggle",
            args: name.map { [.string($0)] } ?? []
        )
    }

    private func writing(_ core: KiwiCore) {
        define(
            core,
            [
                "name": .string("Writing"),
                "apps": .array([.string("test.kiwi.music")]),
                "dim": .number(30),
            ]
        )
    }

    @Test("a named toggle turns the lens on, and its own toggle off")
    func namedToggle() {
        let core = makeCore()
        writing(core)
        define(
            core,
            ["name": .string("Calls"), "apps": .array([.string("x")])]
        )
        var announced: [Bool] = []
        core.vision.onChange = { announced.append($0) }
        #expect(toggle(core, "writing").isSuccess)
        #expect(core.kiwiVisionActive == .lens("Writing"))
        #expect(core.visionLook.dim == 30)
        // Another lens switches without an off between.
        #expect(toggle(core, "Calls").isSuccess)
        #expect(core.kiwiVisionActive == .lens("Calls"))
        #expect(toggle(core, "Calls").isSuccess)
        #expect(core.kiwiVisionActive == .off)
        // A bare toggle turns a lens off, and plain on from off.
        _ = toggle(core, "Writing")
        _ = toggle(core)
        #expect(core.kiwiVisionActive == .off)
        _ = toggle(core)
        #expect(core.kiwiVisionActive == .plain)
        #expect(announced == [true, false, true, false, true])
    }

    @Test("an empty or unknown lens refuses")
    func refusals() {
        let core = makeCore()
        define(core, ["name": .string("Empty")])
        #expect(!toggle(core, "Empty").isSuccess)
        #expect(!toggle(core, "Nowhere").isSuccess)
        #expect(core.kiwiVisionActive == .off)
    }

    @Test("define replaces by name ignoring case; the CLI sends JSON")
    func defineAndDelete() {
        let core = makeCore()
        writing(core)
        define(core, ["name": .string("WRITING"), "dim": .number(70)])
        #expect(core.appWide.visionLenses.map(\.name) == ["WRITING"])
        #expect(
            core.execute(
                "kiwivision.define_lens",
                args: [.string(#"{"name":"Calls","apps":["x"]}"#)]
            ).isSuccess
        )
        #expect(core.appWide.visionLenses.map(\.name) == ["WRITING", "Calls"])
        #expect(
            !core.execute("kiwivision.define_lens", args: [.object([:])])
                .isSuccess
        )
        // Deleting the lens on turns KiwiVision off.
        _ = toggle(core, "calls")
        #expect(
            core.execute("kiwivision.delete_lens", args: [.string("CALLS")])
                .isSuccess
        )
        #expect(core.appWide.visionLenses.map(\.name) == ["WRITING"])
        #expect(core.kiwiVisionActive == .off)
        #expect(
            !core.execute("kiwivision.delete_lens", args: [.string("Calls")])
                .isSuccess
        )
    }

    /// A lens switch is a change of look, so its appearance is paid
    /// through the one door — switched on the way in, back on the way
    /// out — without an announcement between lenses.
    @Test("a lens's appearance is switched on its way in and out")
    func lensAppearance() {
        let system = KiwiVisionAppearanceTests.FakeSystem()
        let core = makeCore(system)
        define(
            core,
            [
                "name": .string("Night"),
                "apps": .array([.string("x")]),
                "appearance": .string("dark"),
            ]
        )
        _ = toggle(core)
        #expect(system.asked.isEmpty, "plain asks for no switch")
        _ = toggle(core, "Night")
        #expect(system.asked == [true])
        _ = toggle(core, "Night")
        #expect(system.asked == [true, false])
    }

    /// Ruling 32: a member's windows all stay clear, or only those
    /// whose title matches; a stranger stays hazed.
    @Test("a lens's members are clear, by title where it says so")
    func membersAreClear() {
        let core = makeCore()
        define(
            core,
            [
                "name": .string("Desk"),
                "apps": .array([
                    .string("test.kiwi.music"), .string("test.kiwi.notes"),
                ]),
                "titles": .object([
                    "test.kiwi.notes": .array([.string("draft")])
                ]),
            ]
        )
        _ = toggle(core, "Desk")
        #expect(core.visionMasks, "a lens with members masks")
        let windows = core.visionMaskWindows(
            target: focused.raw,
            targetPid: 900_020,
            refreshingList: true
        )
        // The two tracked notes windows, then music, then the stranger.
        #expect(windows.map(\.clear) == [true, false, true, false])
        _ = toggle(core)
        #expect(!core.visionMasks)
    }
}
