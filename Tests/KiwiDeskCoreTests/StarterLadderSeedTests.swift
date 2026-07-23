import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The beginner ladder (#466): the pure `StarterLadder` generator,
/// its `Starter` preset faces, and the first-run seed that
/// materializes it as an adopted profile scaled to the displays.
@Suite("Starter ladder & first-run seed (#466)", .serialized)
@MainActor
struct StarterLadderSeedTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-starter-\(UUID().uuidString)"
                )
        )
    }

    private func display(
        _ id: UInt32,
        name: String,
        x: CGFloat
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: 1920, height: 1080)
        )
    }

    private func seedDisplays(_ core: KiwiCore, count: Int) {
        let displays = (0..<count).map {
            display(
                UInt32(10 + $0),
                name: "D\($0)",
                x: CGFloat($0) * 1920
            )
        }
        core.state.apply(.displaysChanged(displays))
    }

    // MARK: - Pure generator

    @Test("space count is five per display")
    func spaceCountScales() {
        #expect(StarterLadder.spaceCount(displayCount: 1) == 5)
        #expect(StarterLadder.spaceCount(displayCount: 2) == 10)
        #expect(StarterLadder.spaceCount(displayCount: 3) == 15)
        // Floored at one screen.
        #expect(StarterLadder.spaceCount(displayCount: 0) == 5)
    }

    @Test("modes ladder repeats per display, bsp omitted")
    func modesLadder() {
        let modes = StarterLadder.spaceModes(displayCount: 2)
        // Block one.
        #expect(modes[SpaceID("1")] == .track)
        #expect(modes[SpaceID("2")] == .stack)
        #expect(modes[SpaceID("3")] == nil)  // bsp ⇒ omitted
        #expect(modes[SpaceID("4")] == .grid)
        #expect(modes[SpaceID("5")] == .floating)
        // Block two mirrors it.
        #expect(modes[SpaceID("6")] == .track)
        #expect(modes[SpaceID("7")] == .stack)
        #expect(modes[SpaceID("8")] == nil)
        #expect(modes[SpaceID("9")] == .grid)
        #expect(modes[SpaceID("10")] == .floating)
    }

    @Test("screens are positional, main omitted")
    func screensPositional() {
        let screens = StarterLadder.spaceScreens(displayCount: 3)
        #expect(screens[SpaceID("1")] == nil)  // main ⇒ omitted
        #expect(screens[SpaceID("5")] == nil)
        #expect(screens[SpaceID("6")] == 1)
        #expect(screens[SpaceID("10")] == 1)
        #expect(screens[SpaceID("11")] == 2)
        #expect(screens[SpaceID("15")] == 2)
        #expect(StarterLadder.screen(of: SpaceID("1")) == 0)
        #expect(StarterLadder.screen(of: SpaceID("6")) == 1)
        #expect(StarterLadder.screen(of: SpaceID("11")) == 2)
    }

    @Test("settings carry the beginner tuning")
    func settingsTuning() {
        let settings = StarterLadder.settings()
        #expect(settings.stack.masterRatio == 0.8)
        #expect(settings.track.newWindow == .ownTrack)
    }

    // MARK: - Preset faces

    @Test("Starter leads each screen count, never the fallback")
    func starterPreset() {
        for count in 1...3 {
            let layouts = StandardProfiles.layouts(for: count)
            #expect(
                layouts.first?.name == "Starter",
                "Starter not first for \(count) screens"
            )
            let starter = layouts.first { $0.name == "Starter" }
            #expect(starter?.isStandard == false)
            #expect(starter?.spaceCount == count * 5)
        }
        // The silent per-count fallback stays a workflow layout.
        #expect(StandardProfiles.standard(for: 1)?.name != "Starter")
    }

    @Test("Starter preset uses the shared generator")
    func starterPresetSharesGenerator() {
        let two = StandardProfiles.layouts(for: 2)
            .first { $0.name == "Starter" }
        #expect(
            two?.spaceModes
                == StarterLadder.spaceModes(displayCount: 2)
        )
        #expect(
            two?.spaceScreens
                == StarterLadder.spaceScreens(displayCount: 2)
        )
    }

    // MARK: - First-run seed

    @Test("gui.json seed scales spaces and digits to displays")
    func seedScalesToDisplays() {
        let core = makeCore()
        seedDisplays(core, count: 2)
        let config = core.guiConfigSeed()
        #expect(
            config.spaces.map(\.raw)
                == (1...10).map { "\($0)" }
        )
        let base = config.modes.first { $0.isDefault }
        let combos = Set((base?.bindings ?? []).map(\.combo))
        // Tenth space binds ⌃⌥0; there is no ⌃⌥6-as-two-digits.
        #expect(combos.contains("control+option+0"))
        #expect(
            (base?.bindings ?? []).contains {
                $0.combo == "control+option+0"
                    && $0.lua == "KiwiDesk.focus_space(\"10\")"
            }
        )
    }

    @Test("single display seeds only five spaces and ⌃⌥1-5")
    func seedSingleDisplay() {
        let core = makeCore()
        seedDisplays(core, count: 1)
        let config = core.guiConfigSeed()
        #expect(config.spaces.count == 5)
        let base = core.guiConfigSeed().modes.first { $0.isDefault }
        let combos = Set((base?.bindings ?? []).map(\.combo))
        #expect(combos.contains("control+option+5"))
        #expect(!combos.contains("control+option+6"))
        #expect(!combos.contains("control+option+0"))
    }

    @Test("first-run profile carries ladder modes, pins, tuning")
    func seedProfileMaterialized() throws {
        let core = makeCore()
        seedDisplays(core, count: 2)
        core.seedFirstRunStarterProfile()

        // Ten live spaces with the ladder modes.
        let modes = Dictionary(
            uniqueKeysWithValues: core.state.workspaces.allSpaces
                .map { ($0.id, $0.mode) }
        )
        #expect(modes[SpaceID("1")] == .track)
        #expect(modes[SpaceID("2")] == .stack)
        #expect(modes[SpaceID("3")] == .bsp)
        #expect(modes[SpaceID("4")] == .grid)
        #expect(modes[SpaceID("5")] == .floating)
        #expect(modes[SpaceID("6")] == .track)

        // Second block pinned to the second display; first block
        // holds the Main role.
        let secondFingerprint = display(11, name: "D1", x: 1920)
            .fingerprint
        #expect(core.spacePins[SpaceID("6")] == secondFingerprint)
        #expect(core.spacePins[SpaceID("1")] == nil)
        #expect(core.mainSpaces.contains(SpaceID("1")))

        // Beginner tuning applied.
        #expect(core.tiler.settings.stack.masterRatio == 0.8)
        #expect(core.tiler.settings.track.newWindow == .ownTrack)

        // Persisted and adopted, so a reload re-applies it.
        #expect(core.profiles.currentName == "Starter")
        let saved = try core.profiles.read(name: "Starter")
        #expect(saved.spaceModes[SpaceID("2")] == .stack)
        #expect(
            saved.spaceModes[SpaceID("9")] == .grid
        )
        // The saved profile carries a real monitor set — both
        // displays — or the first monitor change couldn't match
        // it and would drop it for a composed Standard.
        #expect(saved.monitorSets.first?.monitors.count == 2)
    }

    @Test("empty state falls back to NSScreen for the ladder")
    func seedPopulatesDisplaysFromScreens() {
        // The production path: state has no displays when the seed
        // runs (loadConfig precedes the first publishDisplays).
        // The seed must still populate them from NSScreen so the
        // profile isn't saved with an empty monitor set.
        let core = makeCore()
        #expect(core.state.workspaces.allDisplays.isEmpty)
        core.seedFirstRunStarterProfile()
        // On any real display this authors the profile with a
        // non-empty monitor set; on a headless runner it logs and
        // skips. Either way it never saves an empty-monitor
        // profile that a monitor change would discard.
        if let saved = try? core.profiles.read(name: "Starter") {
            #expect(saved.monitorSets.first?.monitors.isEmpty == false)
            #expect(!core.state.workspaces.allDisplays.isEmpty)
        }
    }
}
