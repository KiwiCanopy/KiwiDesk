import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's settings stored app-wide (#2103, PR 4): `gui.json`
/// carries a `kiwivision` group beside the cue groups, a verb
/// changes the session alone, a row writes the file, and every
/// change of the live values — a reload or a reset included —
/// reaches the plate and the appearance ledger.
@Suite("KiwiVision stored settings")
@MainActor
struct KiwiVisionStoredTests {
    private typealias FakeSystem = KiwiVisionAppearanceTests.FakeSystem

    private func makeCore(
        _ system: FakeSystem = FakeSystem()
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-stored-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        core.vision.appearanceSwitch = system.machine
        return core
    }

    @Test("gui.json carries kiwivision, and its absence reads on")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.visionDim = 35
        value.visionBlur = false
        value.visionAppearance = .opposite
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["kiwivision"] as? [String: Any])
        #expect(group["dim"] as? Double == 35)
        #expect(group["blur"] as? Bool == false)
        #expect(group["appearance"] as? String == "opposite")
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide == value)
        var older = root
        older["kiwivision"] = nil
        let legacy = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: older)
        )
        #expect(legacy.appWide?.visionDim == 60)
        #expect(legacy.appWide?.visionBlur == true)
        #expect(legacy.appWide?.visionAppearance == .unchanged)
    }

    @Test("a stored dim past 0–100 clamps on decode")
    func dimClamps() throws {
        for (raw, dim) in [(140.0, 100.0), (-5, 0), (42.5, 42.5)] {
            let json = """
                {"refusal":{},"kiwivision":{"dim":\(raw)}}
                """
            let config = try JSONDecoder().decode(
                GuiConfig.self,
                from: Data(json.utf8)
            )
            #expect(config.appWide?.visionDim == dim)
        }
    }

    @Test("a verb is a session value; a row writes gui.json")
    func verbIsSessionRowPersists() throws {
        let core = makeCore()
        try core.guiConfigStore.save(GuiConfig())
        #expect(
            core.execute("kiwivision.set_dim", args: [.number(25)])
                .isSuccess
        )
        #expect(core.appWide.visionDim == 25)
        #expect(core.guiConfigStore.load()?.appWide == nil)
        core.setAppWide(persisting: true) { $0.visionBlur = false }
        let stored = try #require(core.guiConfigStore.load()?.appWide)
        #expect(stored.visionBlur == false)
        #expect(stored.visionDim == 60, "the verb's 25 stays session")
    }

    @Test("the plate reads the live values")
    func requestReadsAppWide() {
        let core = makeCore()
        core.setAppWide(persisting: false) { $0.visionDim = 30 }
        #expect(core.visionRequest().dim == 0.3)
    }

    @Test("a row changing the appearance while on switches at once")
    func rowRetargetsWhileOn() {
        let system = FakeSystem()
        let core = makeCore(system)
        core.setKiwiVision(.plain)
        #expect(system.asked.isEmpty)
        core.setAppWide(persisting: true) { $0.visionAppearance = .dark }
        #expect(system.asked == [true])
    }

    @Test("a reset while on takes the appearance home")
    func resetRetargets() {
        let system = FakeSystem()
        let core = makeCore(system)
        _ = core.execute(
            "kiwivision.set_appearance",
            args: [.string("dark")]
        )
        core.setKiwiVision(.plain)
        #expect(system.state.dark)
        core.resetAppWide()
        #expect(core.appWide.visionAppearance == .unchanged)
        #expect(system.asked == [true, false])
        #expect(!system.state.dark)
        #expect(system.debt == nil)
    }

    @Test("a gui.json reload while on follows the stored ask")
    func reloadRetargets() throws {
        let system = FakeSystem()
        let core = makeCore(system)
        var config = GuiConfig()
        var stored = AppWideSettings()
        stored.visionAppearance = .dark
        config.appWide = stored
        try core.guiConfigStore.save(config)
        core.setKiwiVision(.plain)
        #expect(system.asked.isEmpty, "the live ask is still unchanged")
        core.prepareAppWide()
        #expect(core.appWide.visionAppearance == .dark)
        #expect(system.asked == [true])
    }

    /// A shown plate takes a new dim or blur at once, whether a
    /// verb, a row or a reload changed it — not at the next focus
    /// change.
    @Test(
        "every change of the values re-draws a shown plate",
        .enabled(if: !NSScreen.screens.isEmpty, "needs a screen")
    )
    func valuesRedrawThePlate() throws {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { false }
        let core = makeCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        let window = WindowID(1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App1")
            )
        )
        let space = try #require(core.state.workspaces.space(of: window))
        core.state.workspaces.focus(window, in: space)
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        core.noteVisionStandDown([])
        core.setKiwiVision(.plain)
        try #require(plate.dim == 0.6)
        _ = core.execute("kiwivision.set_dim", args: [.number(25)])
        #expect(plate.dim == 0.25)
        core.setAppWide(persisting: false) { $0.visionBlur = false }
        #expect(plate.blur == false)
        core.resetAppWide()
        #expect(plate.dim == 0.6)
        #expect(plate.blur == true)
    }
}
