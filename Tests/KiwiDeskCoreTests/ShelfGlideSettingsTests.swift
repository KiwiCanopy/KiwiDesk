import Foundation
import Testing

@testable import KiwiDeskCore

/// The shelf glide's switch (per profile) and length (app-wide
/// since #3237, #1838): their defaults, the clamp, the wire keys,
/// the verbs that write them, and that the glide the bars play
/// reads them.
@Suite("Shelf glide settings (#1838)")
struct ShelfGlideSettingsTests {
    @Test("Defaults: on, 750 ms")
    func defaults() {
        let animations = AnimationSettings()
        #expect(animations.onExpand)
        #expect(AppWideSettings().animationExpandDurationMS == 750)
        #expect(animations.expandSeconds(at: AppWideSettings()) == 0.75)
    }

    @Test("Off, the glide takes no time")
    func offLands() {
        var animations = AnimationSettings()
        animations.onExpand = false
        #expect(animations.expandSeconds(at: AppWideSettings()) == 0)
    }

    @Test("The wire keys are the Lua names with set_ stripped")
    func wireKeys() throws {
        var settings = TilingSettings()
        settings.animations.onExpand = false
        let data = try JSONEncoder().encode(settings)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        let animations = object?["animations"] as? [String: Any]
        #expect(animations?["on_expand"] as? Bool == false)
        #expect(animations?["expand_duration"] == nil)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.animations == settings.animations)
    }

    @Test("The length clamps to its band on write")
    func clamp() {
        let band = AnimationSettings.expandDurationBand
        var wide = AppWideSettings()
        wide.animationExpandDurationMS = band.lowerBound - 1
        #expect(wide.animationExpandDurationMS == band.lowerBound)
        wide.animationExpandDurationMS = band.upperBound + 1
        #expect(wide.animationExpandDurationMS == band.upperBound)
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
                "animations.set_expand_duration",
                args: [.number(1200)]
            ).isSuccess
        )
        #expect(core.appWide.animationExpandDurationMS == 1200)
        #expect(BarMotion.shelfGlide == 1.2)
        #expect(
            core.execute(
                "animations.set_on_expand",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(!core.tiler.settings.animations.onExpand)
        #expect(BarMotion.shelfGlide == 0)
    }

    /// A dissolve's out-fade is a share of the glide, never the
    /// whole of it.
    @Test("The dissolve's out-fade takes its share of the glide")
    func dissolveOutIsAShare() {
        let whole = 0.75
        let out = BarMotion.dissolveOutDuration(seconds: whole)
        #expect(out == whole * BarMotion.dissolveOutShare)
        #expect(out > 0 && out < whole)
    }

    /// The owner's ruling (2026-10-21): the shelf's expand plays
    /// under Reduce Motion, as its reveal does.
    @Test("The expand still travels under Reduce Motion")
    @MainActor
    func expandPlaysUnderReduceMotion() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let saved = BarMotion.shelfGlide
        defer { BarMotion.shelfGlide = saved }
        BarMotion.shelfGlide = 0.75
        #expect(BarMotion.shelfGlideLength == 0.75)
        var off = AnimationSettings()
        off.onExpand = false
        #expect(off.expandSeconds(at: AppWideSettings()) == 0)
    }
}
