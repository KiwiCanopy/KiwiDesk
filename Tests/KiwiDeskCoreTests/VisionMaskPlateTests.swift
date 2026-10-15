import AppKit
import Testing

@testable import KiwiDeskCore

/// A plate takes its mask from the request (#2103 ruling 21): set
/// only where it changed, and never by an order, since an order is
/// a WindowServer round trip on the switch path (#1925).
@Suite("KiwiVision plate mask")
@MainActor
struct VisionMaskPlateTests {
    private let display = DisplayID(1)
    private let screenFrame = CGRect(x: 0, y: 0, width: 800, height: 600)

    private func manager() -> (VisionManager, () -> [InertVisionPlate]) {
        let vision = VisionManager()
        var made: [InertVisionPlate] = []
        vision.plateFactory = {
            let plate = InertVisionPlate()
            made.append(plate)
            return plate
        }
        vision.reduceMotion = { true }
        vision.isOn = true
        return (vision, { made })
    }

    private func request(
        clear: Bool,
        windows: [CGRect] = []
    ) -> VisionManager.Request {
        VisionManager.Request(
            screens: [(display, screenFrame)],
            target: 7,
            below: nil,
            standDown: [],
            tracked: true,
            dim: 0.6,
            blur: true,
            clearWallpaper: clear,
            windows: windows,
            cornerRadius: 16
        )
    }

    @Test("the whole screen hands the plate no mask")
    func hazedWallpaperUnmasked() throws {
        let (vision, made) = manager()
        vision.sync(request(clear: false), reassert: false)
        let plate = try #require(made().first)
        #expect(plate.shapes.count == 1)
        #expect(plate.shapes.first == .some(nil))
    }

    @Test("a clear wallpaper masks the plate to the windows")
    func windowsMask() throws {
        let (vision, made) = manager()
        let window = CGRect(x: 100, y: 100, width: 300, height: 200)
        vision.sync(request(clear: true, windows: [window]), reassert: false)
        let plate = try #require(made().first)
        let path = try #require(plate.shapes.last ?? nil)
        #expect(path.contains(CGPoint(x: 250, y: 200)))
        #expect(!path.contains(CGPoint(x: 600, y: 500)), "wallpaper")
    }

    @Test("an unchanged mask is not set again, and a mask never orders")
    func reshapeOnlyOnChange() throws {
        let (vision, made) = manager()
        let a = CGRect(x: 100, y: 100, width: 300, height: 200)
        vision.sync(request(clear: true, windows: [a]), reassert: false)
        let plate = try #require(made().first)
        let orders = plate.orders.count
        vision.sync(request(clear: true, windows: [a]), reassert: false)
        #expect(plate.shapes.count == 1, "same windows, no new mask")
        let b = a.offsetBy(dx: 50, dy: 0)
        vision.sync(request(clear: true, windows: [b]), reassert: false)
        #expect(plate.shapes.count == 2)
        #expect(plate.orders.count == orders, "the target never moved")
    }

    @Test("turning the switch off takes the mask away")
    func offUnmasks() throws {
        let (vision, made) = manager()
        let a = CGRect(x: 100, y: 100, width: 300, height: 200)
        vision.sync(request(clear: true, windows: [a]), reassert: false)
        vision.sync(request(clear: false, windows: [a]), reassert: false)
        let plate = try #require(made().first)
        #expect(plate.shapes.last == .some(nil))
    }
}
