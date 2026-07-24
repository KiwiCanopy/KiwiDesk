import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The beginner ladder surviving display changes (#485): an
/// unmatched monitor change recomposes the *ladder* (not a
/// workflow Standard) while the user is on the Starter baseline,
/// and the ⌃⌥N digit shortcuts top up additively for the spaces
/// the change adds.
@Suite("Starter ladder rescale (#485)", .serialized)
@MainActor
struct StarterRescaleTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-rescale-\(UUID().uuidString)"
                )
        )
    }

    /// GUI-managed: a `gui.json` sidecar exists, so a composed
    /// layout may own tiling on an unmatched change (#53).
    private func makeGuiManagedCore() -> KiwiCore {
        let core = makeCore()
        try? core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func display(
        _ id: UInt32,
        _ name: String,
        x: CGFloat = 0
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: 100, height: 100)
        )
    }

    private func connect(_ core: KiwiCore, _ displays: [Display]) {
        for display in displays {
            core.state.workspaces.upsertDisplay(display)
        }
    }

    /// A GUI-managed core seeded onto the one-display Starter
    /// ladder as its adopted, flagged baseline.
    private func onStarterBaseline() throws -> KiwiCore {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        try core.applyStandard(
            StarterLadder.standardLayout(displayCount: 1)
        )
        return core
    }

    // MARK: - Baseline predicate

    @Test("the seeded ladder profile is the starter baseline")
    func seededProfileIsBaseline() throws {
        let core = try onStarterBaseline()
        #expect(core.profiles.currentName == "Starter")
        #expect(
            try core.profiles.read(name: "Starter").isStarterLadder
        )
        #expect(core.isOnStarterBaseline)
    }

    @Test("a workflow preset is not the starter baseline")
    func workflowPresetNotBaseline() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        try core.applyStandard(StandardProfiles.developer)
        #expect(
            try core.profiles.read(name: "Developer")
                .isStarterLadder == false
        )
        #expect(!core.isOnStarterBaseline)
    }

    // MARK: - Fallback recomposition

    @Test("display change recomposes the ladder, not a Standard")
    func displayChangeKeepsLadder() throws {
        let core = try onStarterBaseline()
        // A second display appears; no stored set covers it.
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()

        // Ten spaces on the ladder — not the eight-space Dual
        // Developer workflow Standard.
        #expect(core.profiles.currentStandard == "Starter")
        #expect(core.state.workspaces.allSpaces.count == 10)
        #expect(core.state.workspaces[SpaceID(6)]?.mode == .track)
        #expect(core.state.workspaces[SpaceID(9)]?.mode == .grid)
        // The bsp rung stays bsp, not remapped by a Standard.
        #expect(core.state.workspaces[SpaceID(3)]?.mode == .bsp)
        // Five per display, not the Dual Developer 4/4/2 scatter:
        // each five-space block lands whole on one screen, and the
        // two blocks are on different screens. (Asserted by block
        // cohesion, not fixed ids — the test's live "main" depends
        // on CGMainDisplayID.)
        let blockOne = displaysOf(core, 1...5)
        let blockTwo = displaysOf(core, 6...10)
        #expect(blockOne.count == 1)
        #expect(blockTwo.count == 1)
        #expect(blockOne != blockTwo)
    }

    /// The set of displays the spaces in `range` resolved onto.
    private func displaysOf(
        _ core: KiwiCore,
        _ range: ClosedRange<Int>
    ) -> Set<DisplayID?> {
        Set(
            range.map {
                core.state.workspaces.display(of: SpaceID($0))
            }
        )
    }

    @Test("the ladder baseline is sticky across further changes")
    func ladderStickyAcrossCounts() throws {
        let core = try onStarterBaseline()
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()
        // Now on a transient ladder Standard; a THIRD display must
        // still recompose the ladder (15 spaces), not a Standard.
        connect(core, [display(3, "C", x: 200)])
        core.handleMonitorChange()
        #expect(core.profiles.currentStandard == "Starter")
        #expect(core.state.workspaces.allSpaces.count == 15)
        #expect(core.state.workspaces[SpaceID(11)]?.mode == .track)
        // Three whole five-space blocks, one per display.
        let blocks = [
            displaysOf(core, 1...5),
            displaysOf(core, 6...10),
            displaysOf(core, 11...15),
        ]
        #expect(blocks.allSatisfy { $0.count == 1 })
        #expect(Set(blocks.flatMap { $0 }).count == 3)
    }

    @Test("a non-ladder baseline still falls to a Standard")
    func nonLadderFallsToStandard() throws {
        let core = makeGuiManagedCore()
        connect(core, [display(1, "A")])
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.execute("save_profile", args: [.string("desk")])
        // A second display appears; "desk" covers only one screen
        // and isn't the ladder, so the workflow Standard resolves.
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()
        #expect(core.profiles.currentStandard == "Dual Developer")
        #expect(!core.isOnStarterBaseline)
    }

    // MARK: - Additive shortcut top-up

    @Test("display change tops up ⌃⌥N for the new spaces")
    func displayChangeTopsUpShortcuts() throws {
        let core = try onStarterBaseline()
        // The one-display seed bound ⌃⌥1-5 only.
        let seeded = Set(
            (core.persistedGuiConfig()?.modes
                .first { $0.isDefault }?.bindings ?? [])
                .map(\.combo)
        )
        #expect(seeded.contains("control+option+5"))
        #expect(!seeded.contains("control+option+6"))
        #expect(!seeded.contains("control+option+0"))

        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()

        let grown = Set(
            (core.persistedGuiConfig()?.modes
                .first { $0.isDefault }?.bindings ?? [])
                .map(\.combo)
        )
        // ⌃⌥6-9 and ⌃⌥0 (tenth space) now bound, all three tiers.
        #expect(grown.contains("control+option+6"))
        #expect(grown.contains("control+option+0"))
        #expect(grown.contains("control+option+shift+9"))
        #expect(grown.contains("control+option+command+0"))
        // The original ⌃⌥1-5 are untouched (still present once).
        let goToSix =
            (core.persistedGuiConfig()?.modes
            .first { $0.isDefault }?.bindings ?? [])
            .filter { $0.combo == "control+option+0" }
        #expect(goToSix.count == 1)
        #expect(
            goToSix.first?.lua == "KiwiDesk.focus_space(\"10\")"
        )
    }

    @Test("top-up leaves a user's custom digit chord intact")
    func topUpPreservesCustomChord() throws {
        let core = try onStarterBaseline()
        // The user rebinds ⌃⌥6 in the sidecar before the change.
        var config = core.persistedGuiConfig() ?? GuiConfig()
        let index = config.modes.firstIndex { $0.isDefault }!
        config.modes[index].bindings.append(
            KeyBinding(
                combo: "control+option+6",
                lua: "KiwiDesk.toggle_floating()",
                kind: .custom,
                label: "Mine"
            )
        )
        try core.guiConfigStore.save(config)

        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()

        let sixes =
            (core.persistedGuiConfig()?.modes
            .first { $0.isDefault }?.bindings ?? [])
            .filter { $0.combo == "control+option+6" }
        // Still exactly one ⌃⌥6 — the user's, not overwritten by
        // the default focus_space row.
        #expect(sixes.count == 1)
        #expect(sixes.first?.lua == "KiwiDesk.toggle_floating()")
    }
}
