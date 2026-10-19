import AppKit
import Testing

@testable import KiwiDeskCore

/// The leave fade's gate in the plates (#2417): a plate already
/// shown fades the window focus left, on the screen it lies on,
/// only when the focus moved, and never under Reduce Motion, a lens
/// hold or a duration of 0.
@Suite("KiwiVision leave fade")
@MainActor
struct VisionLeaveFadeTests {
    private let left = DisplayID(1)
    private let right = DisplayID(2)

    private func manager(
        reduceMotion: Bool = false
    ) -> (VisionManager, () -> [InertVisionPlate]) {
        let vision = VisionManager()
        var made: [InertVisionPlate] = []
        vision.plateFactory = {
            let plate = InertVisionPlate()
            made.append(plate)
            return plate
        }
        vision.reduceMotion = { reduceMotion }
        vision.active = .plain
        return (vision, { made })
    }

    /// The window left lies on the left screen (x 100–200).
    private func leaving(seconds: Double = 0.6) -> VisionManager.Leaving {
        VisionManager.Leaving(
            window: VisionMask.Window(
                frame: CGRect(x: 110, y: 10, width: 40, height: 30),
                cornerRadius: 8,
                clear: false
            ),
            duration: seconds,
            curve: .linear
        )
    }

    private func request(
        target: CGWindowID,
        leaving: VisionManager.Leaving? = nil,
        holding: CGWindowID? = nil
    ) -> VisionManager.Request {
        VisionManager.Request(
            screens: [left, right].map {
                (
                    $0,
                    CGRect(x: Int($0.raw) * 100, y: 0, width: 100, height: 80)
                )
            },
            target: target,
            below: nil,
            standDown: [],
            tracked: true,
            dim: 0.4,
            blur: true,
            clearWallpaper: false,
            windows: [],
            holding: holding,
            leaving: leaving
        )
    }

    @Test("a focus change fades the window left, on its own screen")
    func fadesTheWindowLeft() throws {
        let (vision, made) = manager()
        vision.sync(request(target: 7), reassert: false)
        vision.sync(request(target: 8, leaving: leaving()), reassert: false)
        let plates = made()
        #expect(plates.count == 2)
        let fades = plates.map(\.fades)
        #expect(fades[0].count == 1)
        #expect(fades[1].isEmpty)
        let fade = try #require(fades[0].first)
        #expect(fade.duration == 0.6)
        #expect(fade.curve == .linear)
        // The plate's own coordinates: the screen's origin is 100.
        #expect(
            fade.region.boundingBox
                == CGRect(x: 10, y: 10, width: 40, height: 30)
        )
    }

    @Test("the same target, or a first show, fades nothing")
    func onlyAMoveFades() {
        let (vision, made) = manager()
        vision.sync(request(target: 7, leaving: leaving()), reassert: false)
        vision.sync(request(target: 7, leaving: leaving()), reassert: false)
        #expect(made().allSatisfy { $0.fades.isEmpty })
    }

    @Test("Reduce Motion, a hold and a duration of 0 stand it down")
    func standDowns() {
        let (calm, calmMade) = manager(reduceMotion: true)
        calm.sync(request(target: 7), reassert: false)
        calm.sync(request(target: 8, leaving: leaving()), reassert: false)
        #expect(calmMade().allSatisfy { $0.fades.isEmpty })

        let (held, heldMade) = manager()
        held.sync(request(target: 7), reassert: false)
        held.sync(
            request(target: 8, leaving: leaving(), holding: 8),
            reassert: false
        )
        #expect(heldMade().allSatisfy { $0.fades.isEmpty })

        let (instant, instantMade) = manager()
        instant.sync(request(target: 7), reassert: false)
        instant.sync(
            request(target: 8, leaving: leaving(seconds: 0)),
            reassert: false
        )
        #expect(instantMade().allSatisfy { $0.fades.isEmpty })
    }
}
