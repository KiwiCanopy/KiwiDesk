import Testing

@testable import KiwiDeskCore

/// The plates' luma measure (#786, #2859): Rec. 709 weights over
/// the encoded channels, a translucent colour laid over its
/// ground at its own alpha before the distance is taken.
@Suite("ColorVision luma")
struct ColorVisionLumaTests {
    @Test("luma weighs the encoded channels")
    func lumaWeighsEncodedChannels() throws {
        #expect(ColorVision.luma("#FFFFFF") == 0.2126 + 0.7152 + 0.0722)
        #expect(ColorVision.luma("#000000") == 0)
        let green = try #require(ColorVision.luma("#00FF00"))
        #expect(abs(green - 0.7152) < 1e-12)
        #expect(ColorVision.luma("nope") == nil)
    }

    @Test("distance composites the top over its ground")
    func distanceComposites() throws {
        let opaque = try #require(
            ColorVision.lumaDistance("#FFFFFF", over: "#000000")
        )
        #expect(abs(opaque - 1) < 1e-9)
        let half = try #require(
            ColorVision.lumaDistance("#FFFFFF80", over: "#000000")
        )
        #expect(abs(half - 128.0 / 255) < 1e-9)
        #expect(
            ColorVision.lumaDistance("#12251A", over: "#12251A") == 0
        )
        #expect(ColorVision.lumaDistance("#FFFFFF", over: "x") == nil)
    }
}
