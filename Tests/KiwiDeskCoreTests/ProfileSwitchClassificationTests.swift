import Foundation
import Testing

@testable import KiwiDeskCore

/// WHICH applies count as a profile switch (#1230) — the one
/// question that gates both the snapshot and the restore. Split
/// from `ProfilePartitioningTests` at the §2.1 ceiling along its
/// own seam: that suite is what a switch DOES to windows, this
/// one is when an apply is a switch at all.
///
/// **Three states, not two.** A re-apply of the LIVE profile is
/// not a switch, so a monitor reconnect cannot revert the user's
/// own moves. The session's FIRST apply is not one either —
/// pruning there would drop the Spaces the boot restore just
/// rebuilt. A built-in Standard hands the live slot back empty,
/// and the apply after it IS a switch whenever that profile has
/// an arrangement to put back.
///
/// Conflating the two nil cases breaks one end or the other:
/// treating them both as switches makes boot destructive, and
/// treating them both as non-switches makes the apply after a
/// Standard silently fall back to the pre-#1230 name-match. Both
/// halves shipped during this lane, one after the other.
@Suite("Which applies are profile switches (#1230)", .serialized)
@MainActor
struct ProfileSwitchClassificationTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-switchclass-\(UUID().uuidString)"
                )
        )
    }

    private func profile(
        _ name: String,
        spaces: [SpaceID]
    ) -> Profile {
        var modes: [SpaceID: LayoutMode] = [:]
        for space in spaces { modes[space] = .bsp }
        return Profile(
            name: name,
            monitorSets: [],
            spaces: spaces,
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    private func live(_ core: KiwiCore, _ ids: [Int]) {
        for id in ids {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "App\(id)"
                )
            )
        }
    }

    private func members(
        _ core: KiwiCore,
        _ space: SpaceID
    ) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    /// A re-apply of the LIVE profile files nothing and restores
    /// nothing, so a monitor reconnect cannot revert the user's
    /// own moves.
    @Test("Re-applying the live profile changes nothing")
    func sameProfileReapplyIsIdentity() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        // The user then moves w2 across.
        core.state.workspaces.add(WindowID(2), to: "1")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1), WindowID(2)])
        #expect(members(core, "2").isEmpty)
    }

    /// The session's FIRST apply has nothing to replace, and
    /// pruning would drop the Spaces the boot restore just
    /// rebuilt (`ProfileSpaceReconcileTests` holds the
    /// hardware-apply half of the same contract).
    @Test("The session's first apply prunes nothing")
    func firstApplyIsNotASwitch() {
        let core = makeCore()
        live(core, [1])
        core.state.workspaces.ensureSpace("restored")
        core.state.workspaces.add(WindowID(1), to: "restored")
        core.apply(
            profile: profile("A", spaces: ["1", "2"]),
            forceRetile: false
        )
        #expect(core.state.workspaces["restored"] != nil)
        #expect(members(core, "restored") == [WindowID(1)])
    }

    /// After a Standard the live slot is empty, and "no live
    /// profile" must not read as "not a switch" — the next apply
    /// would skip the restore and fall back to the pre-#1230
    /// name-match for that one apply.
    @Test("A profile after a Standard still restores")
    func restoresAfterAStandard() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(2), to: "1")
        // A Standard composes in between — a preset apply, or the
        // monitor-change fallback.
        core.apply(
            composed: ProfileComposition.Composed(
                sourceName: "Std",
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                assignment: [:],
                settings: TilingSettings()
            ),
            forceRetile: false
        )
        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }
}
