import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Motion in the look (#2176, owner ruling 2026-10-12): every
/// animation field is a look path, a look the user saves carries
/// it, and a bundled look and the tour's paint say nothing about
/// it — picking a picture never changes how fast things move.
@Suite("Look motion (#2176)")
struct LookMotionTests {
    private var tuned: TilingSettings {
        var settings = TilingSettings()
        settings.animations.durationMS = 400
        settings.animations.onShelf = false
        return settings
    }

    @Test("motion is every animation field, apart from styling")
    func motionIsEveryAnimationField() {
        #expect(
            Set(LookKeys.motion)
                == Set(
                    AnimationSettings.CodingKeys.allCases.map {
                        "animations.\($0.stringValue)"
                    }
                )
        )
        #expect(Set(LookKeys.motion).isDisjoint(with: LookKeys.styling))
        #expect(LookKeys.all == LookKeys.styling + LookKeys.motion)
    }

    @Test("no bundled look carries motion")
    func bundledLooksCarryNoMotion() {
        let looks = LookCatalog.bundled(
            sizes: [CGSize(width: 1440, height: 900)]
        )
        #expect(looks.count > 1)
        for look in looks {
            #expect(
                Set(look.style.keys).isDisjoint(with: LookKeys.motion),
                "\(look.name) carries motion"
            )
        }
    }

    /// A tuned speed keeps a bundled tile markable.
    @Test("a bundled look stays applied over tuned animations")
    func bundledTileIgnoresMotion() throws {
        let glass = try #require(
            LookCatalog.bundled(
                sizes: [CGSize(width: 1440, height: 900)]
            ).first
        )
        var settings = tuned
        glass.apply(to: &settings)
        #expect(glass.isStyleApplied(to: settings))
        #expect(settings.animations.durationMS == 400)
    }

    @Test("a saved look carries motion and applies it")
    func savedLookCarriesMotion() {
        let look = LookBody(of: tuned).named("Mine")
        var settings = TilingSettings()
        look.admitted.apply(to: &settings)
        #expect(settings.animations == tuned.animations)
    }

    @MainActor
    @Test("the tour's paint and its Revert leave motion alone")
    func tourLeavesMotion() {
        let mine = LookBody(of: TilingSettings()).named("Mine")
        let painted = KiwiCore.painted(tuned, look: mine, palette: nil)
        #expect(painted.animations == tuned.animations)
        let reverted = KiwiCore.unpainted(tuned, to: TilingSettings())
        #expect(reverted.animations == tuned.animations)
    }

    @Test("a motion value is read by the config's own decoder")
    func motionValuesAreDecoded() {
        let look = ShelfLook(
            name: "Mine",
            style: [
                "animations.duration": .number(5000),
                "animations.on_shelf": .bool(false),
                "animations.space_change": .string("slide"),
                "animations.scroll_duration": .string("fast"),
            ],
            colors: [:]
        )
        var settings = TilingSettings()
        // Off its default, so a skip and a reset tell apart.
        settings.animations.scrollDurationMS = 400
        look.apply(to: &settings)
        // Clamped as a stored file would be; a wrong type skipped.
        #expect(settings.animations.durationMS == 1000)
        #expect(!settings.animations.onShelf)
        #expect(settings.animations.spaceChange == .slide)
        #expect(settings.animations.scrollDurationMS == 400)
    }
}
