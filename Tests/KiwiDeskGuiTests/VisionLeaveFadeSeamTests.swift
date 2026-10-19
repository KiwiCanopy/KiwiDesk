import Foundation
import Testing

/// The leave fade's order against the plate's (#2417, borders.md ▸
/// KiwiVision): `sync` starts the fade through the one
/// `fadeLeaving` before it orders the plate, and `fadeLeaving`
/// commits the fade's masks first — or the order lands ahead of the
/// mask and the window focus left is covered whole for a frame. No
/// headless suite sees that frame, so its shape is held here.
@Suite("KiwiVision leave fade seam")
struct VisionLeaveFadeSeamTests {
    @Test("sync starts the fade before it orders the plate")
    func fadePrecedesTheOrder() throws {
        let body = try SourceScan.functionBody(
            of: "sync",
            in: "VisionManager.swift",
            under: "Vision"
        )
        let fade = try #require(body.range(of: "fadeLeaving("))
        let order = try #require(body.range(of: "order(plate,"))
        #expect(fade.lowerBound < order.lowerBound)
    }

    @Test("fadeLeaving commits the mask once, and only it starts one")
    func fadeLeavingFlushes() throws {
        let body = try SourceScan.functionBody(
            of: "fadeLeaving",
            in: "VisionManager+Fade.swift",
            under: "Vision"
        )
        let flushes = body.components(separatedBy: "CATransaction.flush()")
        #expect(flushes.count == 2)
        let fade = try #require(body.range(of: ".fadeIn("))
        let flush = try #require(body.range(of: "CATransaction.flush()"))
        #expect(fade.lowerBound < flush.lowerBound)
        let manager = try SourceScan.functionBody(
            of: "sync",
            in: "VisionManager.swift",
            under: "Vision"
        )
        #expect(!manager.contains(".fadeIn("))
    }
}
