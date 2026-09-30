import Foundation
import Testing

@testable import KiwiDeskCore

/// WHICH applies count as a profile switch (#1230) — the one
/// question that gates both the snapshot and the restore. Split
/// from `ProfilePartitioningTests` at the §2.1 ceiling along its
/// own seam: that suite is what a switch DOES to windows, this
/// one is when an apply is a switch at all.
///
/// A re-apply of the LIVE arrangement is not a switch, so a
/// monitor reconnect cannot revert the user's own moves. The
/// session's FIRST apply is not one either — pruning there would
/// drop the Spaces the boot restore just rebuilt. A composed
/// Standard is live AS ITSELF since #1829, so the apply after it
/// is a switch like any other, record or none; before that it
/// handed the slot back empty, and the two nil cases — treated
/// alike — shipped one broken end after the other.
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
        core.apply(profile: a, cause: .event)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        // The user then moves w2 across.
        core.state.workspaces.add(WindowID(2), to: "1")

        core.apply(profile: a, cause: .event)
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
            cause: .event
        )
        #expect(core.state.workspaces["restored"] != nil)
        #expect(members(core, "restored") == [WindowID(1)])
    }

    /// The apply after a Standard restores the profile's own
    /// arrangement rather than name-matching into the Standard's.
    @Test("A profile after a Standard still restores")
    func restoresAfterAStandard() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        core.apply(profile: a, cause: .event)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        core.apply(profile: b, cause: .event)
        core.state.workspaces.add(WindowID(2), to: "1")
        // A Standard composes in between — a preset apply, or the
        // monitor-change fallback.
        core.apply(
            composed: ProfileComposition.Composed(
                sourceName: "Std",
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                assignment: [:],
                settings: TilingSettings(),
                sourceTitle: nil
            ),
            forceRetile: false
        )
        core.apply(profile: a, cause: .event)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }

    /// A Standard → profile apply is a switch even where the
    /// profile has no record (#1829): the Standard's undeclared
    /// Spaces are pruned into the profile's fallback, as any
    /// other arrangement's are.
    @Test("A profile after a Standard is a switch, record or none")
    func standardToProfileIsASwitch() {
        let core = makeCore()
        live(core, [1])
        core.apply(
            composed: ProfileComposition.Composed(
                sourceName: "Std",
                spaces: ["1", "9"],
                spaceModes: ["1": .bsp, "9": .bsp],
                assignment: [:],
                settings: TilingSettings(),
                sourceTitle: nil
            ),
            forceRetile: false
        )
        core.state.workspaces.add(WindowID(1), to: "9")

        core.apply(profile: profile("P", spaces: ["1"]), cause: .event)
        #expect(core.state.workspaces["9"] == nil)
        #expect(members(core, "1") == [WindowID(1)])
    }
}
