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
