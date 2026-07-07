import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// Write-path round-trip tests for space-order preservation (#75).
// Exercises the CAPTURE path: load_profile + save_profile, where
// the live WorkspaceManager order is seeded by apply(profile:)
// and then read back by buildProfile.  The existing
// `rehomeUsesStoredOrder` test in ProfileSpaceReconcileTests
// hand-builds a Profile and calls apply() directly; these tests
// go through the command path so the full encode→disk→load→live
// →encode cycle is exercised.

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-order-\(UUID().uuidString)"
            )
    )
}

/// A display named `name` with a 100×100 frame.
/// Fingerprint: `"<name>:100x100"`.
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

@MainActor
private func connect(
    _ core: KiwiCore,
    _ displays: [Display]
) {
    for d in displays { core.state.workspaces.upsertDisplay(d) }
}

@Suite("Space order write-path round-trip (#75)", .serialized)
@MainActor
struct ProfileSpaceOrderTests {

    // MARK: load → save preserves stored order

    /// The core defect: `apply(profile:)` used to iterate
    /// `declaredSpaces` (a Set) when calling `ensureSpace`,
    /// so WorkspaceManager.order became Set-hash order instead
    /// of the profile's stored display order.  A subsequent
    /// `save_profile` then captured that scrambled order into
    /// `Profile.spaces`.
    ///
    /// Fix: iterate `profile.orderedSpaces` (not the Set).
    @Test("load_profile + save_profile preserves stored order")
    func loadSavePreservesOrder() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])

        // Write a profile directly (bypassing buildProfile) so
        // we can set the stored `spaces` to a non-sorted order
        // ["z","m","a"] that is distinct from both numeric-
        // ascending and alphabetical order.  All three IDs are
        // unknown to the live state (it only has SpaceID(1) from
        // StateCoordinator.init), so they will be created fresh
        // by the ensureSpace loop inside apply(profile:) and the
        // insertion order is what the test verifies.
        let stored = Profile(
            name: "ordered",
            monitorSets: [
                MonitorSet(monitors: ["A:100x100"])
            ],
            spaces: [
                SpaceID("z"),
                SpaceID("m"),
                SpaceID("a"),
            ],
            spaceModes: [
                SpaceID("z"): .stack,
                SpaceID("m"): .bsp,
                SpaceID("a"): .grid,
            ],
            settings: TilingSettings()
        )
        try core.profiles.save(stored)

        // load_profile: "z","m","a" don't exist yet in live
        // state; SpaceID(1) (the init default) is stale and
        // gets pruned.  Before the fix the three new spaces were
        // created in Set-hash order; after the fix they follow
        // orderedSpaces = ["z","m","a"].
        let load = core.execute(
            "load_profile",
            args: [.string("ordered")]
        )
        #expect(load.isSuccess)

        // save_profile: buildProfile captures allSpaces in
        // WorkspaceManager.order, which is now ["z","m","a"].
        core.execute(
            "save_profile",
            args: [.string("ordered")]
        )

        let after = try core.profiles.read(name: "ordered")
        // Order must survive the full load→save round-trip.
        #expect(
            after.spaces == [
                SpaceID("z"),
                SpaceID("m"),
                SpaceID("a"),
            ]
        )
    }

    // MARK: reorder of EXISTING spaces reconciles live order

    /// The #55 fix for the inherited #75 seam: `ensureSpace`
    /// early-returns for existing spaces, so a live save used
    /// to capture the OLD creation order even when the GUI
    /// showed a reordered list (masked only by prose guards).
    /// `applyProfileScopedState` now reconciles the live order
    /// to the GUI display order via `WorkspaceManager.reorder`,
    /// so the live save and `overwriteProfile` capture ONE
    /// order representation.
    @Test("live save after GUI reorder of existing spaces")
    func liveSaveAfterReorder() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])

        // Existing live spaces, creation order one,two,three.
        core.state.workspaces.ensureSpace(SpaceID("one"))
        core.state.workspaces.ensureSpace(SpaceID("two"))
        core.state.workspaces.ensureSpace(SpaceID("three"))

        // The GUI shows (and applies) the reversed order.
        var config = GuiConfig()
        config.spaces = [
            SpaceID("three"), SpaceID("two"),
            SpaceID("one"), SpaceID(1),
        ]
        core.applyProfileScopedState(from: config)

        // The LIVE save path must capture the display order.
        try core.persistProfile(named: "reordered")
        let saved = try core.profiles.read(name: "reordered")
        #expect(saved.spaces == config.spaces)
    }

    /// `WorkspaceManager.reorder` semantics: spaces in
    /// `desired` lead in that order; unmentioned spaces keep
    /// their relative order after them; unknown ids in
    /// `desired` are ignored (no phantom spaces).
    @Test("reorder primitive: partial list, unknown ids")
    func reorderPrimitive() {
        var manager = WorkspaceManager()
        manager.ensureSpace(SpaceID("a"))
        manager.ensureSpace(SpaceID("b"))
        manager.ensureSpace(SpaceID("c"))
        manager.ensureSpace(SpaceID("d"))

        manager.reorder(matching: [
            SpaceID("c"), SpaceID("ghost"), SpaceID("a"),
        ])

        let order = manager.allSpaces.map(\.id)
        #expect(
            order == [
                SpaceID("c"), SpaceID("a"),
                SpaceID("b"), SpaceID("d"),
            ]
        )
    }

    // MARK: live order beats a stale sidecar list

    /// The live order (reconciled on every apply/save) beats
    /// a stale sidecar list: after loading a profile whose
    /// order differs from gui.json, live editing must show —
    /// and a live Update must capture — the profile's order,
    /// not the sidecar's (#55 final review M2).
    @Test("loadGuiConfig prefers live order over stale sidecar")
    func liveOrderBeatsStaleSidecar() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])
        // Sidecar remembers an old display order.
        var sidecar = GuiConfig()
        sidecar.spaces = [
            SpaceID("a"), SpaceID("m"), SpaceID("z"),
        ]
        try core.guiConfigStore.save(sidecar)
        // Live state reconciled to a profile order z,m.
        core.state.workspaces.ensureSpace(SpaceID("a"))
        core.state.workspaces.ensureSpace(SpaceID("m"))
        core.state.workspaces.ensureSpace(SpaceID("z"))
        core.state.workspaces.reorder(matching: [
            SpaceID("z"), SpaceID("m"),
        ])

        let cfg = core.loadGuiConfig()

        let interesting = cfg.spaces.filter {
            ["z", "m", "a"].contains($0.raw)
        }
        #expect(
            interesting == [
                SpaceID("z"), SpaceID("m"), SpaceID("a"),
            ]
        )
    }

    // MARK: sidecar and profile agree after load

    /// After loading a profile with stored order ["z","m","a"],
    /// `loadGuiConfig()` (which seeds from live state when no
    /// sidecar exists) must return the same order — not the
    /// alphabetical sort that the old Set-iteration produced.
    @Test("guiConfigSeed reflects stored order after load")
    func seedReflectsStoredOrderAfterLoad() throws {
        let core = makeCore()
        connect(core, [display(1, "A")])

        let stored = Profile(
            name: "q",
            monitorSets: [
                MonitorSet(monitors: ["A:100x100"])
            ],
            spaces: [
                SpaceID("z"),
                SpaceID("m"),
                SpaceID("a"),
            ],
            spaceModes: [
                SpaceID("z"): .bsp,
                SpaceID("m"): .bsp,
                SpaceID("a"): .bsp,
            ],
            settings: TilingSettings()
        )
        try core.profiles.save(stored)

        let load = core.execute(
            "load_profile",
            args: [.string("q")]
        )
        #expect(load.isSuccess)

        // No sidecar → guiConfigSeed() uses allSpaces order.
        let cfg = core.loadGuiConfig()
        // Spaces section must agree with the profile's order.
        let profileSpaces = [
            SpaceID("z"), SpaceID("m"), SpaceID("a"),
        ]
        #expect(cfg.spaces == profileSpaces)
    }
}
