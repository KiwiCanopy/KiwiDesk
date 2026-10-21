import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's dim and blur verbs (#2103, ruling 10 as amended
/// 2026-10-14): dim takes the whole 0–100 % in Lua as in the GUI,
/// default 60 %; the glass blur is ON by default, and Reduce
/// transparency stands it down while the dim stays. Asserts read
/// the plate request, which outlives where the values are stored.
/// `.serialized`: `LiquidGlassGate.override` is process-global,
/// so each test restores the value it found.
@Suite("KiwiVision dim and blur", .serialized)
@MainActor
struct KiwiVisionSettingsTests {
    private let w1 = WindowID(1)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-settings-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    /// Runs `body` with Reduce transparency read as `reduced`,
    /// handing neighbours back the value they pinned.
    private func withTransparency(
        reduced: Bool,
        _ body: () throws -> Void
    ) rethrows {
        let before = LiquidGlassGate.override
        defer { LiquidGlassGate.override = before }
        LiquidGlassGate.override = { reduced }
        try body()
    }

    @Test("defaults: 60 % dim, blur on")
    func defaults() {
        withTransparency(reduced: false) {
            let request = makeCore().visionRequest()
            #expect(request.dim == 0.6)
            #expect(request.blur)
        }
    }

    @Test("set_dim takes 0–100 and refuses past it")
    func setDim() {
        let core = makeCore()
        for (percent, dim) in [(65.0, 0.65), (0, 0), (100, 1)] {
            #expect(
                core.execute(
                    "kiwivision.set_dim",
                    args: [.number(percent)]
                ).isSuccess
            )
            #expect(core.visionRequest().dim == CGFloat(dim))
        }
        for bad: JSONValue in [.number(-1), .number(101), .bool(true)] {
            #expect(
                !core.execute("kiwivision.set_dim", args: [bad])
                    .isSuccess
            )
        }
        #expect(core.visionRequest().dim == 1)
    }

    @Test("set_blur switches the blur the request carries")
    func setBlur() {
        withTransparency(reduced: false) {
            let core = makeCore()
            #expect(
                core.execute("kiwivision.set_blur", args: [.bool(false)])
                    .isSuccess
            )
            #expect(!core.visionRequest().blur)
            _ = core.execute("kiwivision.set_blur", args: [.bool(true)])
            #expect(core.visionRequest().blur)
            #expect(
                !core.execute("kiwivision.set_blur", args: [.number(1)])
                    .isSuccess
            )
        }
    }

    @Test("Reduce transparency stands the blur down, not the dim")
    func reduceTransparency() {
        withTransparency(reduced: true) {
            let core = makeCore()
            _ = core.execute("kiwivision.set_blur", args: [.bool(true)])
            _ = core.execute("kiwivision.set_dim", args: [.number(50)])
            #expect(!core.visionRequest().blur)
            #expect(core.visionRequest().dim == 0.5)
        }
    }

    @Test(
        "a flip of Reduce transparency re-draws the plates",
        .enabled(if: !NSScreen.screens.isEmpty, "needs a screen")
    )
    func flipRedraws() throws {
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)
        try withTransparency(reduced: false) {
            let core = makeCore()
            core.tiler.visibleBounds = { _ in screen }
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: w1, pid: 1, appName: "App1")
                )
            )
            let space = try #require(core.state.workspaces.space(of: w1))
            core.state.workspaces.focus(w1, in: space)
            let plate = InertVisionPlate()
            core.vision.plateFactory = { plate }
            core.vision.active = .plain
            core.noteVisionStandDown([])
            core.updateVision()
            try #require(!core.vision.plates.isEmpty)
            #expect(plate.blur == true)
            LiquidGlassGate.override = { true }
            core.reduceTransparencyDidChange()
            #expect(plate.blur == false)
        }
    }

    @Test("the blur is Liquid Glass clear, hud where glass cannot draw")
    func blurIsGlassClear() throws {
        let blur = VisionVeil.makeBlur()
        if #available(macOS 26.0, *) {
            let glass = try #require(blur as? NSGlassEffectView)
            #expect(glass.style == .clear)
            #expect(glass.cornerRadius == 0)
            #expect(glass.appearance?.name == .darkAqua)
        } else {
            let hud = try #require(blur as? NSVisualEffectView)
            #expect(hud.material == .hudWindow)
            #expect(hud.blendingMode == .behindWindow)
        }
    }

    @Test("the real plate shows its blur only when asked, under the dim")
    func realPlateDrawsTheBlur() {
        let plate = AppKitVisionPlate()
        let frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        plate.update(frame: frame, dim: 0.6, blur: false)
        #expect(plate.blurShown == false)
        plate.update(frame: frame, dim: 0.6, blur: true)
        #expect(plate.blurShown == true)
        #expect(plate.dimAboveBlur)
        plate.update(frame: frame, dim: 0.6, blur: false)
        #expect(plate.blurShown == false)
    }
}
