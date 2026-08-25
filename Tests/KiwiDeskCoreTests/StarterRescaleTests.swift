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
        makeTestCore(
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
            StarterSetup.standardLayout(
                displays: [display(1, "A")],
                mainID: DisplayID(1)
            )
        )
        return core
    }

    // MARK: - Baseline predicate

    @Test("the seeded ladder profile is the starter baseline")
    func seededProfileIsBaseline() throws {
        let core = try onStarterBaseline()
        #expect(core.profiles.currentName == "Starter")
        #expect(
            try core.profiles.read(name: "Starter").isStarterSetup
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
                .isStarterSetup == false
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

        // The two-screen budget is five spaces — not the
        // eight-space Dual Developer workflow Standard. The
        // fixtures are 100 pt wide, so both screens are
        // `ScreenClass.laptop` and take that class's list.
        #expect(core.profiles.currentStandard == "Starter")
        #expect(core.state.workspaces.allSpaces.count == 5)
        #expect(
            core.state.workspaces[SpaceID(1)]?.mode == .scrolling
        )
        #expect(
            core.state.workspaces[SpaceID(2)]?.mode == .monocle
        )
        #expect(
            core.state.workspaces[SpaceID(3)]?.mode == .floating
        )
        // Each screen's block lands whole on one screen, and the
        // two blocks are on different screens. (Asserted by block
        // cohesion, not fixed ids — the test's live "main" depends
        // on CGMainDisplayID.) The blocks are no longer equal:
        // the widest screen takes the larger share.
        let blockOne = displaysOf(core, 1...3)
        let blockTwo = displaysOf(core, 4...5)
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
        // Now on a transient Starter Standard; a THIRD display
        // must still recompose the setup (the seven-space budget),
        // not a workflow Standard.
        connect(core, [display(3, "C", x: 200)])
        core.handleMonitorChange()
        #expect(core.profiles.currentStandard == "Starter")
        #expect(core.state.workspaces.allSpaces.count == 7)
        // Space 6 opens the third display's block, so it is that
        // screen's LEAD (#1018) rather than the head of its list.
        #expect(
            core.state.workspaces[SpaceID(6)]?.mode == .monocle
        )
        // Three whole blocks, one per display — 3 · 2 · 2, the
        // widest screen taking the larger share.
        let blocks = [
            displaysOf(core, 1...3),
            displaysOf(core, 4...5),
            displaysOf(core, 6...7),
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

    @Test("saving a recomposed ladder Standard stays the baseline")
    func savingTransientLadderKeepsFlag() throws {
        let core = try onStarterBaseline()
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()
        // A transient Starter Standard is on screen (5 spaces).
        #expect(core.profiles.currentStandard == "Starter")
        // The user saves it under a new name.
        core.execute("save_profile", args: [.string("Both")])
        // buildProfile tags it from currentStandard, so the saved
        // profile is still the ladder baseline — a later change
        // won't drop them to a workflow Standard.
        #expect(try core.profiles.read(name: "Both").isStarterSetup)
        #expect(core.isOnStarterBaseline)
    }

    @Test("a reload on the transient ladder re-applies the ladder")
    func reloadKeepsLadder() throws {
        let core = try onStarterBaseline()
        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()
        #expect(core.state.workspaces.allSpaces.count == 5)
        // The profile re-apply a config reload performs must keep
        // the starter setup, not recompose the workflow Standard
        // (#485, the second recompose site).
        core.reapplyActiveProfileState()
        #expect(core.profiles.currentStandard == "Starter")
        #expect(core.state.workspaces.allSpaces.count == 5)
        let blockTwo = displaysOf(core, 4...5)
        #expect(blockTwo.count == 1)
        #expect(displaysOf(core, 1...3) != blockTwo)
    }

    // MARK: - Additive shortcut top-up

    @Test("display change tops up ⌃⌥N for the new spaces")
    func displayChangeTopsUpShortcuts() throws {
        let core = try onStarterBaseline()
        // The one-display seed bound ⌃⌥1-3 only (the one-screen
        // budget is three spaces).
        let seeded = Set(
            (core.persistedGuiConfig()?.layers
                .first { $0.isDefault }?.bindings ?? [])
                .map(\.combo)
        )
        #expect(seeded.contains("control+option+3"))
        #expect(!seeded.contains("control+option+4"))
        #expect(!seeded.contains("control+option+0"))

        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()

        let grown = Set(
            (core.persistedGuiConfig()?.layers
                .first { $0.isDefault }?.bindings ?? [])
                .map(\.combo)
        )
        // ⌃⌥4-5 (the spaces the second screen added) now bound,
        // all three tiers.
        #expect(grown.contains("control+option+4"))
        #expect(grown.contains("control+option+5"))
        #expect(grown.contains("control+option+shift+5"))
        #expect(grown.contains("control+option+command+5"))
        // The original ⌃⌥1-3 are untouched (still present once).
        let goToFive =
            (core.persistedGuiConfig()?.layers
            .first { $0.isDefault }?.bindings ?? [])
            .filter { $0.combo == "control+option+5" }
        #expect(goToFive.count == 1)
        #expect(
            goToFive.first?.lua == "KiwiDesk.focus_space(\"5\")"
        )
    }

    @Test("top-up leaves a user's custom digit chord intact")
    func topUpPreservesCustomChord() throws {
        let core = try onStarterBaseline()
        // ⌃⌥5, deliberately: the second display grows the setup
        // from three spaces to five, so this is a digit the
        // top-up WANTS. Keyed on a digit outside the grown range
        // the test passes without the collision ever occurring —
        // which is what it did when the budget was five per
        // display and this fixture said ⌃⌥6 (#678 pass 11).
        let contested = "control+option+5"
        var config = core.persistedGuiConfig() ?? GuiConfig()
        let index = config.layers.firstIndex { $0.isDefault }!
        config.layers[index].bindings.append(
            KeyBinding(
                combo: contested,
                lua: "KiwiDesk.toggle_floating()",
                kind: .custom,
                label: "Mine"
            )
        )
        try core.guiConfigStore.save(config)

        connect(core, [display(2, "B", x: 100)])
        core.handleMonitorChange()

        // Vacuity: the change must actually have reached a fifth
        // space, or the top-up had no reason to want this digit.
        #expect(core.state.workspaces.allSpaces.count == 5)
        let claimed =
            (core.persistedGuiConfig()?.layers
            .first { $0.isDefault }?.bindings ?? [])
            .filter { $0.combo == contested }
        // Still exactly one ⌃⌥5 — the user's, not overwritten by
        // the default focus_space row.
        #expect(claimed.count == 1)
        #expect(claimed.first?.lua == "KiwiDesk.toggle_floating()")
    }
}
