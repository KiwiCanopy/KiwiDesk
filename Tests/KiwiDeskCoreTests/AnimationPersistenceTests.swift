import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-anim-\(UUID().uuidString)"
            )
    )
}

private func display(
    _ id: UInt32,
    _ name: String
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
}

/// Pins the issue #51 split: `animations.duration` and
/// `animations.scroll_speed` are separate persisted knobs,
/// each synced to the AnimationEngine on profile apply.
@Suite("Animation duration persistence", .serialized)
@MainActor
struct AnimationPersistenceTests {
    // MARK: - Round-trip

    @Test("duration and scroll_speed round-trip through JSON")
    func roundTrip() throws {
        var settings = TilingSettings()
        settings.animations.durationMS = 350
        settings.animations.scrollSpeedMS = 150
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: data
        )
        #expect(decoded.animations.durationMS == 350)
        #expect(decoded.animations.scrollSpeedMS == 150)
    }

    @Test("Pre-issue-51 profile (no keys) keeps 250 ms defaults")
    func legacyProfileDefaults() throws {
        // A profile saved before issue #51 has no duration keys.
        let json = #"{"animations":{"on_scrolling":false}}"#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.durationMS == 250)
        #expect(decoded.animations.scrollSpeedMS == 250)
    }

    // MARK: - Commands

    @Test("animations.set_duration persists in settings")
    func setDurationPersists() {
        let core = makeCore()
        let response = core.execute(
            "animations.set_duration",
            args: [.number(400)]
        )
        #expect(response.isSuccess)
        #expect(core.tiler.animation.durationMS == 400)
        // Persisted so a profile save captures it.
        #expect(
            core.tiler.settings.animations.durationMS == 400
        )
    }

    @Test("animations.set_scroll_speed persists in settings")
    func setScrollSpeedPersists() {
        let core = makeCore()
        let response = core.execute(
            "animations.set_scroll_speed",
            args: [.number(150)]
        )
        #expect(response.isSuccess)
        #expect(
            core.tiler.animation.scrollDurationMS == 150
        )
        #expect(
            core.tiler.settings.animations.scrollSpeedMS == 150
        )
    }

    @Test("duration clamped to 50–1000 on engine AND settings")
    func durationClamping() {
        let core = makeCore()
        core.execute(
            "animations.set_duration",
            args: [.number(10)]
        )
        #expect(core.tiler.animation.durationMS == 50)
        // The persisted copy must clamp too, else the profile
        // JSON and the GUI stepper show an out-of-range value.
        #expect(
            core.tiler.settings.animations.durationMS == 50
        )
        core.execute(
            "animations.set_duration",
            args: [.number(5000)]
        )
        #expect(core.tiler.animation.durationMS == 1000)
        #expect(
            core.tiler.settings.animations.durationMS == 1000
        )
    }

    @Test("scroll_speed clamps on the settings copy too")
    func scrollSpeedClampingPersists() {
        let core = makeCore()
        core.execute(
            "animations.set_scroll_speed",
            args: [.number(9000)]
        )
        #expect(
            core.tiler.settings.animations.scrollSpeedMS == 1000
        )
        #expect(
            core.tiler.animation.scrollDurationMS == 1000
        )
    }

    @Test("hand-edited out-of-range JSON decodes clamped")
    func decodeClampsOutOfRange() throws {
        let json = #"""
            {"animations":{"duration":5000,"scroll_speed":5}}
            """#
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data(json.utf8)
        )
        #expect(decoded.animations.durationMS == 1000)
        #expect(decoded.animations.scrollSpeedMS == 50)
    }

    // MARK: - Profile apply sync

    @Test("apply(profile:) syncs both durations to engine")
    func profileApplySyncs() throws {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(display(1, "A"))
        var settings = TilingSettings()
        settings.animations.durationMS = 450
        settings.animations.scrollSpeedMS = 120
        let profile = Profile(
            name: "test",
            monitorSets: [
                MonitorSet(monitors: ["A:100x100"])
            ],
            spaceModes: [SpaceID(1): .bsp],
            settings: settings
        )
        try core.profiles.save(profile)
        core.execute(
            "load_profile",
            args: [.string("test")]
        )
        #expect(core.tiler.animation.durationMS == 450)
        #expect(
            core.tiler.animation.scrollDurationMS == 120
        )
    }

    @Test("applyProfileScopedState syncs the engine (GUI apply)")
    func guiApplySyncsEngine() {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(display(1, "A"))
        // Engine starts at defaults; a GUI live-apply must push
        // the incoming settings onto the engine so the retile it
        // triggers doesn't animate at the stale duration.
        var config = GuiConfig()
        config.settings.animations.durationMS = 470
        config.settings.animations.scrollSpeedMS = 130
        config.spaces = [SpaceID(1)]
        core.applyProfileScopedState(from: config)
        #expect(core.tiler.animation.durationMS == 470)
        #expect(
            core.tiler.animation.scrollDurationMS == 130
        )
    }

    @Test("profile round-trip: save then load restores values")
    func profileSaveLoad() throws {
        let core = makeCore()
        core.state.workspaces.upsertDisplay(display(1, "A"))
        // Set via commands — both are now persisted.
        core.execute(
            "animations.set_duration",
            args: [.number(380)]
        )
        core.execute(
            "animations.set_scroll_speed",
            args: [.number(160)]
        )
        // Save and wipe.
        core.execute(
            "save_profile",
            args: [.string("durtest")]
        )
        core.tiler.animation.durationMS = 250
        core.tiler.animation.scrollDurationMS = 250
        // Load should restore both.
        core.execute(
            "load_profile",
            args: [.string("durtest")]
        )
        #expect(core.tiler.animation.durationMS == 380)
        #expect(
            core.tiler.animation.scrollDurationMS == 160
        )
    }
}
