import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's dim and blur verbs (#2103, ruling 10 as amended
/// 2026-10-14): dim takes the whole 0–100 % in Lua as in the GUI,
/// default 60 %; the glass blur is ON by default, and Reduce
/// transparency stands it down while the dim stays.
/// `.serialized`: `LiquidGlassGate.override` is process-global.
@Suite("KiwiVision dim and blur", .serialized)
@MainActor
struct KiwiVisionSettingsTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-settings-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    @Test("defaults: 60 % dim, blur on")
    func defaults() {
        let core = makeCore()
        #expect(core.vision.dim == 0.6)
        #expect(core.vision.blur)
    }

    @Test("set_dim takes 0–100 and refuses past it")
    func setDim() {
        let core = makeCore()
        #expect(
            core.execute("kiwivision.set_dim", args: [.number(65)])
                .isSuccess
        )
        #expect(core.vision.dim == 0.65)
        #expect(
            core.execute("kiwivision.set_dim", args: [.number(0)])
                .isSuccess
        )
        #expect(core.vision.dim == 0)
        #expect(
            core.execute("kiwivision.set_dim", args: [.number(100)])
                .isSuccess
        )
        #expect(core.vision.dim == 1)
        for bad: JSONValue in [.number(-1), .number(101), .bool(true)] {
            #expect(
                !core.execute("kiwivision.set_dim", args: [bad])
                    .isSuccess
            )
        }
        #expect(core.vision.dim == 1)
    }

    @Test("set_blur switches the blur the request carries")
    func setBlur() {
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = nil }
        let core = makeCore()
        #expect(
            core.execute("kiwivision.set_blur", args: [.bool(false)])
                .isSuccess
        )
        #expect(!core.vision.blur)
        #expect(!core.visionRequest().blur)
        _ = core.execute("kiwivision.set_blur", args: [.bool(true)])
        #expect(core.visionRequest().blur)
        #expect(
            !core.execute("kiwivision.set_blur", args: [.number(1)])
                .isSuccess
        )
    }

    @Test("Reduce transparency stands the blur down, not the dim")
    func reduceTransparency() {
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = nil }
        let core = makeCore()
        _ = core.execute("kiwivision.set_blur", args: [.bool(true)])
        _ = core.execute("kiwivision.set_dim", args: [.number(50)])
        #expect(!core.visionRequest().blur)
        #expect(core.visionRequest().dim == 0.5)
    }

    @Test("a flip of Reduce transparency re-draws the plates")
    func flipRedraws() {
        let core = makeCore()
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        core.vision.isOn = true
        _ = core.execute("kiwivision.set_blur", args: [.bool(true)])
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = nil }
        core.noteVisionStandDown([])
        core.updateVision()
        // A host with no screen draws no plate to read.
        guard core.vision.plates.isEmpty == false else { return }
        #expect(plate.blur == true)
        LiquidGlassGate.override = { true }
        core.reduceTransparencyDidChange()
        #expect(plate.blur == false)
    }

    @Test("the blur is Liquid Glass clear, hud where glass cannot draw")
    func blurIsGlassClear() throws {
        let blur = AppKitVisionPlate.makeBlur()
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
}
