import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `float_size` (#3554): the stored shape, its strict decode, the
/// setter, and its place in the placement's precedence —
/// remembered frame, then `float_size`, then the derived size.
@Suite("Float size setting", .serialized)
@MainActor
struct FloatSizeSettingTests {
    private let slot = CGRect(x: 40, y: 60, width: 300, height: 900)

    private func root(_ settings: TilingSettings) throws -> [String: Any] {
        let data = try JSONEncoder().encode(settings)
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func decode(_ json: String) throws -> TilingSettings {
        try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
    }

    @Test("stored as float_size, absent while unset")
    func storedShape() throws {
        var settings = TilingSettings()
        #expect(try root(settings)["float_size"] == nil)
        settings.floatSize = FloatSize(width: 1100, height: 800)
        let size = try #require(
            try root(settings)["float_size"] as? [String: Double]
        )
        #expect(size == ["width": 1100, "height": 800])
        let back = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONEncoder().encode(settings)
        )
        #expect(back.floatSize == settings.floatSize)
    }

    @Test(
        "the decoder refuses a size no window can take",
        arguments: [
            #"{"width": 0, "height": 800}"#,
            #"{"width": 1100, "height": -5}"#,
            #"{"width": 1100}"#,
        ]
    )
    func strictDecode(size: String) {
        #expect(throws: DecodingError.self) {
            try decode(#"{"float_size": \#(size)}"#)
        }
    }

    @Test("the setter takes two positive numbers, none clears")
    func setter() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-fs-\(UUID().uuidString)")
        )
        #expect(
            core.execute(
                "set_float_size",
                args: [.number(1100), .number(800)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.floatSize
                == FloatSize(width: 1100, height: 800)
        )
        for bad: [JSONValue] in [
            [.number(0), .number(800)],
            [.number(1100)],
            [.string("big"), .number(800)],
        ] {
            #expect(!core.execute("set_float_size", args: bad).isSuccess)
        }
        #expect(core.tiler.settings.floatSize != nil)
        #expect(core.execute("set_float_size").isSuccess)
        #expect(core.tiler.settings.floatSize == nil)
    }

    @Test("an asked size is capped to a small region, and says so")
    func cappedSize() {
        let region = CGRect(x: 0, y: 25, width: 900, height: 600)
        let answer = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 1100, height: 400)
        )
        #expect(answer.size == CGSize(width: 900, height: 400))
        #expect(answer.width == FloatPlacement.SizeLimit.region)
        #expect(answer.height == nil)
        let tall = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 400, height: 800)
        )
        #expect(tall.size == CGSize(width: 400, height: 600))
        #expect(tall.height == FloatPlacement.SizeLimit.region)
    }

    @Test("the clamp order names the limit that decided each axis")
    func clampOrder() {
        let region = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let answer = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 1200, height: 200),
            minimum: CGSize(width: 0, height: 300),
            maximum: CGSize(width: 900, height: CGFloat.infinity)
        )
        #expect(answer.size == CGSize(width: 900, height: 300))
        #expect(answer.width == FloatPlacement.SizeLimit.ceiling)
        #expect(answer.height == FloatPlacement.SizeLimit.floor)
        let derived = FloatPlacement.defaultSize(
            in: region,
            maximum: CGSize(width: 500, height: CGFloat.infinity)
        )
        #expect(derived.size.width == 500)
        #expect(derived.width == nil)
    }

    @Test("a locked ratio fits the ask, never under the floor")
    func ratioFit() {
        let region = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let fitted = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 800, height: 800),
            ratio: 2
        )
        #expect(fitted.size == CGSize(width: 800, height: 400))
        #expect(fitted.width == nil)
        #expect(fitted.height == FloatPlacement.SizeLimit.ceiling)
        let floored = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 800, height: 800),
            minimum: CGSize(width: 0, height: 500),
            ratio: 2
        )
        #expect(floored.size == CGSize(width: 1000, height: 500))
    }

    @Test("a sub-point miss names no limit")
    func slackIsQuiet() {
        let region = CGRect(x: 0, y: 0, width: 900.4, height: 600)
        let sizing = FloatPlacement.defaultSize(
            in: region,
            asked: CGSize(width: 900.6, height: 400)
        )
        #expect(sizing.width == nil)
    }

    /// Two windows on space 1, w2 tiled and focused at `slot`.
    private func makeCore(
        applied: @escaping @MainActor (WindowID, CGRect) -> Void
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-fs-\(UUID().uuidString)")
        )
        let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        core.tiler.visibleBounds = { _ in screen }
        core.tiler.allScreenBounds = { [screen] }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 900_001,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(.windowResized(WindowID(2), slot))
        core.state.apply(.windowFocused(WindowID(2)))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in applied(id, frame) }
        return core
    }

    @Test("make_floating centres at float_size over the derived size")
    func floatSizeOutranksDerived() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.tiler.settings.floatSize = FloatSize(width: 700, height: 500)
        #expect(core.execute("make_floating").isSuccess)
        let frame = try #require(frames[WindowID(2)])
        let region = try #require(core.floatGrowBounds(of: WindowID(2)))
        #expect(frame.size == CGSize(width: 700, height: 500))
        #expect(abs(frame.midX - region.midX) < 0.001)
        #expect(abs(frame.midY - region.midY) < 0.001)
    }

    @Test("a remembered float frame outranks float_size")
    func rememberedOutranks() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        core.tiler.settings.floatSize = FloatSize(width: 700, height: 500)
        let saved = CGRect(x: 200, y: 150, width: 640, height: 420)
        core.state.floatFrames[WindowID(2)] = .init(
            pid: 900_001,
            frame: saved
        )
        #expect(core.execute("make_floating").isSuccess)
        #expect(frames[WindowID(2)] == saved)
    }
}
