import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The starter setup (#466, re-derived from screen shapes by #678
/// Phase 4 pass 11): the pure `StarterSetup` generator, its
/// `Starter` preset face, and the first-run seed that materializes
/// it as an adopted profile.
///
/// The fixtures are 1920 × 1080, which is `ScreenClass.desktop` —
/// pinned by `expectedDesktopClass` below, because every expected
/// mode in this suite is that class's list and a moved threshold
/// would otherwise rewrite them all silently.
@Suite("Starter setup & first-run seed (#466)", .serialized)
@MainActor
struct StarterSetupSeedTests {
    private let fixture = CGSize(width: 1920, height: 1080)

    private func makeCore() -> KiwiCore {
        makeTestCore(
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
            frame: CGRect(
                x: x,
                y: 0,
                width: fixture.width,
                height: fixture.height
            )
        )
    }

    private func seedDisplays(_ core: KiwiCore, count: Int) {
        let displays = (0..<count).map {
            display(
                UInt32(10 + $0),
                name: "D\($0)",
                x: CGFloat($0) * fixture.width
            )
        }
        core.state.apply(.displaysChanged(displays))
    }

    private func sizes(_ count: Int) -> [CGSize] {
        [CGSize](repeating: fixture, count: count)
    }

    @Test("the fixture screen is the class this suite assumes")
    func expectedDesktopClass() {
        #expect(ScreenClass.of(fixture) == .desktop)
    }

    // MARK: - Pure generator

    @Test("space count follows the budget, not the display count")
    func spaceCountFollowsBudget() {
        // The retired ladder gave five per display. The budget
        // grows sub-linearly instead: eight spaces on day one is
        // eight keys to learn, most of them empty.
        #expect(StarterSetup.spaceCount(sizes: sizes(1)) == 3)
        #expect(StarterSetup.spaceCount(sizes: sizes(2)) == 5)
        #expect(StarterSetup.spaceCount(sizes: sizes(3)) == 7)
        // Floored at one screen.
        #expect(StarterSetup.spaceCount(sizes: []) == 3)
    }

    @Test("modes are the screen's own list, largest screen first")
    func modesComeFromTheScreen() {
        let modes = StarterSetup.spaceModes(sizes: sizes(2))
        // Main screen (largest by tie-break) takes the head of
        // the desktop list plus the one Floating space.
        #expect(modes[SpaceID("1")] == .grid)
        #expect(modes[SpaceID("2")] == .stack)
        #expect(modes[SpaceID("3")] == .floating)
        // The second screen continues down the same list rather
        // than repeating what the first took.
        #expect(modes[SpaceID("4")] == .bsp)
        #expect(modes[SpaceID("5")] == .scrolling)
    }

    @Test("screens are positional, main omitted")
    func screensPositional() {
        let screens = StarterSetup.spaceScreens(sizes: sizes(2))
        #expect(screens[SpaceID("1")] == nil)  // main ⇒ omitted
        #expect(screens[SpaceID("3")] == nil)
        #expect(screens[SpaceID("4")] == 1)
        #expect(screens[SpaceID("5")] == 1)
    }

    @Test("every space is pinned or on main, none unaccounted")
    func everySpaceLandsOnAScreen() {
        let all = StarterSetup.spaces(sizes: sizes(3))
        let screens = StarterSetup.spaceScreens(sizes: sizes(3))
        // The map is sparse by design, so the assertion is that
        // no space names a screen that does not exist — the
        // blocks are no longer equal, so `(n - 1) / 5` cannot
        // stand in for this.
        #expect(all.count == 7)
        for space in all {
            let screen = screens[space] ?? 0
            #expect(screen >= 0 && screen < 3)
        }
        #expect(Set(screens.values) == [1, 2])
        // The map's SIZE, not just one nil: "main ⇒ omitted"
        // rested on a single `== nil`, and a pin drift that kept
        // every secondary index correct passed everything else
        // (guard-prover, 2026-08-11).
        let offMain = StarterSetup.slots(sizes(3))
            .filter { $0.screen >= 1 }
        #expect(screens.count == offMain.count)
        #expect(offMain.count < all.count)
    }

    @Test("tuning follows the MAIN screen's class")
    func tuningFollowsMainScreen() {
        let settings = StarterTuning.settings(mainShape: .desktop)
        #expect(settings.stack.masterRatio == 0.8)
        #expect(settings.track.newWindow == .ownTrack)
        // At 2560 pt a three-column grid gives 850 pt cells.
        #expect(settings.grid.columns == 2)
        #expect(settings.grid.rows == 2)
        // A laptop cannot spare 40 pt of chrome per edge.
        let small = StarterTuning.settings(mainShape: .laptop)
        #expect(small.gapsGlobal == .uniform(6))
        #expect(small.appBarStyle.thickness == 28)
        #expect(small.spaceBarStyle.thickness == 28)
        // Everything that assumes width has to flip.
        let tall = StarterTuning.settings(mainShape: .pivoted)
        #expect(tall.stack.stackPosition == .bottom)
        #expect(tall.scrolling.orientation == .vertical)
        #expect(tall.grid.splitDirection == .vertical)
        // One master on a 3440 pt screen is an absurd pane.
        let wide = StarterTuning.settings(mainShape: .ultrawide)
        #expect(wide.stack.masterCount == 2)
        #expect(wide.track.autoTracks)
        #expect(wide.minWindowSize == 420)
    }

    // MARK: - Preset face

    @Test("Starter leads its own count and is never the fallback")
    func starterPreset() {
        for count in 1...3 {
            let live = sizes(count)
            let layouts = StandardProfiles.layouts(
                for: count,
                sizes: live
            )
            #expect(
                layouts.first?.name == "Starter",
                "Starter not first for \(count) screens"
            )
            let starter = layouts.first { $0.name == "Starter" }
            #expect(starter?.isStandard == false)
            #expect(
                starter?.spaceCount
                    == StarterAllocation.budget(screenCount: count)
            )
        }
        // The silent per-count fallback stays a workflow layout,
        // and answers without any screens at all.
        #expect(
            StandardProfiles.standard(for: 1)?.name != "Starter"
        )
    }

    @Test("there is one Starter, and it is for the live screens")
    func oneStarterForTheLiveScreens() {
        let live = sizes(2)
        let catalog = StandardProfiles.all(sizes: live)
        let starters = catalog.filter { $0.name == "Starter" }
        #expect(starters.count == 1)
        #expect(starters.first?.screenCount == 2)
        // A count you are not running has no screen shapes to
        // choose layouts from, so it offers none.
        #expect(
            StandardProfiles.layouts(for: 3, sizes: live)
                .allSatisfy { $0.name != "Starter" }
        )
        #expect(
            StandardProfiles.workflows
                .allSatisfy { $0.name != "Starter" }
        )
    }

    @Test("Starter preset uses the shared generator")
    func starterPresetSharesGenerator() {
        let live = sizes(2)
        let two = StandardProfiles.layouts(for: 2, sizes: live)
            .first { $0.name == "Starter" }
        #expect(
            two?.spaceModes == StarterSetup.spaceModes(sizes: live)
        )
        #expect(
            two?.spaceScreens
                == StarterSetup.spaceScreens(sizes: live)
        )
        #expect(
            two?.settings
                == StarterTuning.settings(
                    mainShape: ScreenClass.of(live[0])
                )
        )
    }

    // MARK: - First-run seed

    @Test("gui.json seed scales spaces and digits to displays")
    func seedScalesToDisplays() {
        let core = makeCore()
        seedDisplays(core, count: 2)
        let config = core.guiConfigSeed()
        #expect(
            config.spaces.map(\.raw) == (1...5).map { "\($0)" }
        )
        let base = config.layers.first { $0.isDefault }
        let combos = Set((base?.bindings ?? []).map(\.combo))
        #expect(combos.contains("control+option+5"))
        #expect(!combos.contains("control+option+6"))
        #expect(
            (base?.bindings ?? []).contains {
                $0.combo == "control+option+5"
                    && $0.lua == "KiwiDesk.focus_space(\"5\")"
            }
        )
    }

    @Test("a single display seeds three spaces and ⌃⌥1-3")
    func seedSingleDisplay() {
        let core = makeCore()
        seedDisplays(core, count: 1)
        let config = core.guiConfigSeed()
        #expect(config.spaces.count == 3)
        let base = config.layers.first { $0.isDefault }
        let combos = Set((base?.bindings ?? []).map(\.combo))
        #expect(combos.contains("control+option+3"))
        #expect(!combos.contains("control+option+4"))
        #expect(!combos.contains("control+option+0"))
    }

    @Test("first-run profile carries modes, pins, tuning")
    func seedProfileMaterialized() throws {
        let core = makeCore()
        seedDisplays(core, count: 2)
        core.seedFirstRunStarterProfile()

        let modes = Dictionary(
            uniqueKeysWithValues: core.state.workspaces.allSpaces
                .map { ($0.id, $0.mode) }
        )
        #expect(modes[SpaceID("1")] == .grid)
        #expect(modes[SpaceID("2")] == .stack)
        #expect(modes[SpaceID("3")] == .floating)
        #expect(modes[SpaceID("4")] == .bsp)
        #expect(modes[SpaceID("5")] == .scrolling)

        // The second screen's block is pinned to it; the first
        // block holds the Main role.
        let secondFingerprint = display(
            11,
            name: "D1",
            x: fixture.width
        ).fingerprint
        #expect(core.spacePins[SpaceID("4")] == secondFingerprint)
        #expect(core.spacePins[SpaceID("1")] == nil)
        #expect(core.mainSpaces.contains(SpaceID("1")))

        // Tuning applied, from the main screen's class.
        #expect(core.tiler.settings.stack.masterRatio == 0.8)
        #expect(core.tiler.settings.track.newWindow == .ownTrack)
        #expect(core.tiler.settings.grid.columns == 2)

        // Persisted and adopted, so a reload re-applies it.
        #expect(core.profiles.currentName == "Starter")
        let saved = try core.profiles.read(name: "Starter")
        #expect(saved.spaceModes[SpaceID("2")] == .stack)
        #expect(saved.spaceModes[SpaceID("4")] == .bsp)
        // The saved profile carries a real monitor set — both
        // displays — or the first monitor change couldn't match
        // it and would drop it for a composed Standard.
        #expect(saved.monitorSets.first?.monitors.count == 2)
    }

    @Test("empty state falls back to NSScreen for the setup")
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
            #expect(
                saved.monitorSets.first?.monitors.isEmpty == false
            )
            #expect(!core.state.workspaces.allDisplays.isEmpty)
        }
    }
}
