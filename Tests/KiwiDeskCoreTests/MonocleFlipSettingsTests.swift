import Foundation
import Testing

@testable import KiwiDeskCore

/// The two `animations` leaves the Monocle flip adds (#1391):
/// their defaults, their clamp, their wire keys and the verbs
/// that write them.
@Suite("Monocle flip settings (#1391)")
struct MonocleFlipSettingsTests {
    @Test("Defaults: on, 450 ms")
    func defaults() {
        let animations = AnimationSettings()
        #expect(animations.onMonocleFocus)
        #expect(animations.monocleFlipDurationMS == 450)
    }

    @Test("A profile without the keys keeps the defaults")
    func absentKeysDecodeToDefaults() throws {
        let json = #"{"animations":{"on_scrolling":false}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.onMonocleFocus)
        #expect(decoded.animations.monocleFlipDurationMS == 450)
    }

    @Test("The wire keys are the Lua names with set_ stripped")
    func wireKeys() throws {
        var settings = TilingSettings()
        settings.animations.onMonocleFocus = false
        settings.animations.monocleFlipDurationMS = 300
        let data = try JSONEncoder().encode(settings)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        let animations = object?["animations"] as? [String: Any]
        #expect(animations?["on_monocle_focus"] as? Bool == false)
        #expect(animations?["monocle_flip_duration"] as? Int == 300)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.animations == settings.animations)
    }

    @Test("The duration clamps to 100–1000 on decode and on write")
    func clamp() throws {
        var animations = AnimationSettings()
        animations.monocleFlipDurationMS = 5
        #expect(animations.monocleFlipDurationMS == 100)
        animations.monocleFlipDurationMS = 5000
        #expect(animations.monocleFlipDurationMS == 1000)
        let json = #"{"animations":{"monocle_flip_duration":20}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.monocleFlipDurationMS == 100)
    }

    @Test("The verbs write the settings")
    @MainActor
    func verbsWrite() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "animations.set_on_monocle_focus",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.animations.onMonocleFocus)
        #expect(
            core.execute(
                "animations.set_monocle_flip_duration",
                args: [.number(600)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.animations.monocleFlipDurationMS == 600
        )
        #expect(
            !core.execute(
                "animations.set_monocle_flip_duration",
                args: [.string("slow")]
            ).isSuccess
        )
    }
}
