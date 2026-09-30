import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf glide's two `animations` leaves (#1838): their
/// defaults, their clamp, their wire keys, the verbs that write
/// them, and that the glide the bars play reads them.
@Suite("Shelf glide settings (#1838)")
struct ShelfGlideSettingsTests {
    @Test("Defaults: on, 750 ms")
    func defaults() {
        let animations = AnimationSettings()
        #expect(animations.onShelf)
        #expect(animations.shelfDurationMS == 750)
        #expect(animations.shelfGlideSeconds == 0.75)
    }

    @Test("Off, the glide takes no time")
    func offLands() {
        var animations = AnimationSettings()
        animations.onShelf = false
        #expect(animations.shelfGlideSeconds == 0)
    }

    @Test("The wire keys are the Lua names with set_ stripped")
    func wireKeys() throws {
        var settings = TilingSettings()
        settings.animations.onShelf = false
        settings.animations.shelfDurationMS = 1500
        let data = try JSONEncoder().encode(settings)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        let animations = object?["animations"] as? [String: Any]
        #expect(animations?["on_shelf"] as? Bool == false)
        #expect(animations?["shelf_duration"] as? Int == 1500)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.animations == settings.animations)
    }

    @Test("The duration clamps to its band on decode and on write")
    func clamp() throws {
        let band = AnimationSettings.shelfDurationBand
        var animations = AnimationSettings()
        animations.shelfDurationMS = band.lowerBound - 1
        #expect(animations.shelfDurationMS == band.lowerBound)
        animations.shelfDurationMS = band.upperBound + 1
        #expect(animations.shelfDurationMS == band.upperBound)
        let json = #"{"animations":{"shelf_duration":20}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.shelfDurationMS == band.lowerBound)
    }

    /// The verbs write the settings AND the pace the bars glide
    /// on, which `updateBars()` hands `BarMotion`.
    @Test("The verbs write the settings and the bars' pace")
    @MainActor
    func verbsWrite() {
        let before = BarMotion.shelfGlide
        defer { BarMotion.shelfGlide = before }
        let core = makeTestCore()
        #expect(
            core.execute(
                "animations.set_shelf_duration",
                args: [.number(1200)]
            ).isSuccess
        )
        #expect(core.tiler.settings.animations.shelfDurationMS == 1200)
        #expect(BarMotion.shelfGlide == 1.2)
        #expect(
            core.execute(
                "animations.set_on_shelf",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.animations.onShelf)
        #expect(BarMotion.shelfGlide == 0)
    }
}
