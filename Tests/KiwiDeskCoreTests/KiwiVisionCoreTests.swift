import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision through a live core (#2103): the verb toggles it,
/// the plates keep the focus anchor clear — or an own key window
/// that is not it, as the ring stands down for one (#933) — and
/// the target's WindowServer reorder event re-stacks them.
@Suite("KiwiVision core wiring")
@MainActor
struct KiwiVisionCoreTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-vision-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        for id: UInt32 in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: w1)!
        core.state.workspaces.focus(w1, in: space)
        core.eventLoop.ownKeyWindow = { nil }
        return core
    }

    @Test("the verb toggles the mode and the GUI hears it")
    func verbToggles() {
        let core = makeCore()
        var heard: [Bool] = []
        core.vision.onChange = { heard.append($0) }
        let on = core.execute("kiwivision.toggle")
        #expect(on.isSuccess)
        #expect(core.kiwiVisionIsOn)
        _ = core.execute("kiwivision.toggle")
        #expect(!core.kiwiVisionIsOn)
        #expect(heard == [true, false])
    }

    @Test("the focus anchor is the window kept clear")
    func anchorIsTheTarget() {
        let core = makeCore()
        #expect(core.visionRequest().target == w1.raw)
        #expect(core.visionRequest().dim == KiwiCore.visionDim)
    }

    @Test("an own key window that is not the anchor stays clear")
    func ownKeyWindowIsTheTarget() {
        let core = makeCore()
        core.eventLoop.ownKeyWindow = {
            OwnKeyWindowReading(number: 999_999, isDialog: false)
        }
        #expect(core.visionRequest().target == 999_999)
        #expect(core.visionRequest().below == nil)
    }

    @Test("the anchor as own key window keeps the anchor's request")
    func anchorAsOwnKeyWindow() {
        let core = makeCore()
        core.eventLoop.ownKeyWindow = { [w1] in
            OwnKeyWindowReading(number: Int(w1.raw), isDialog: false)
        }
        #expect(core.visionRequest().target == w1.raw)
    }

    @Test("the target's reorder re-stacks the plates under it")
    func reorderTeeRestacks() {
        let core = makeCore()
        let plate = InertVisionPlate()
        core.vision.plateFactory = { plate }
        core.vision.isOn = true
        core.vision.sync(
            VisionManager.Request(
                screens: [
                    (DisplayID(1), CGRect(x: 0, y: 0, width: 9, height: 9))
                ],
                target: w1.raw,
                below: nil,
                standDown: [],
                dim: 0.4
            ),
            reassert: false
        )
        core.visionTargetReordered(w2)
        #expect(plate.orders == [w1.raw])
        core.visionTargetReordered(w1)
        #expect(plate.orders == [w1.raw, w1.raw])
    }

    @Test("updateBorders re-draws the plates")
    func bordersDriveTheVision() {
        let core = makeCore()
        var made = 0
        core.vision.plateFactory = {
            made += 1
            return InertVisionPlate()
        }
        core.vision.isOn = true
        core.updateBorders()
        // One plate per screen not standing down; at least the
        // request ran, which a host with no screen cannot show.
        #expect(core.vision.target == w1.raw)
        #expect(made == core.vision.plates.count)
    }

    @Test("stopping the core turns KiwiVision off")
    func stopClears() {
        let core = makeCore()
        core.vision.isOn = true
        core.stop()
        #expect(!core.kiwiVisionIsOn)
    }
}
