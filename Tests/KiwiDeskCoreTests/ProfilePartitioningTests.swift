import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile owns its own partitioning of the windows on the
/// Desktop (#1230). The name stays a Space's identity; the
/// PROFILE is the scope it resolves in, so two profiles may each
/// declare a `1` and they are different Spaces.
///
/// The suite is a device measurement made repeatable. On
/// 2026-09-04, with Starter holding Space 1 (5 windows) and Space
/// 3 (3 windows), `load_profile ProbeB` then `load_profile
/// Starter` returned Space 1 with all 8 windows and Space 3
/// EMPTY: the round trip destroyed the arrangement, because
/// `ensureSpace` name-matched profile B's `1` onto profile A's
/// and `pruneSpaces` forwarded the rest away for good.
@Suite("Per-profile Space partitioning (#1230)", .serialized)
@MainActor
struct ProfilePartitioningTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-partition-\(UUID().uuidString)"
                )
        )
    }

    private func profile(
        _ name: String,
        spaces: [SpaceID],
        modes: [SpaceID: LayoutMode] = [:]
    ) -> Profile {
        var resolved = modes
        for space in spaces where resolved[space] == nil {
            resolved[space] = .bsp
        }
        return Profile(
            name: name,
            monitorSets: [],
            spaces: spaces,
            spaceModes: resolved,
            settings: TilingSettings()
        )
    }

    /// Registers `ids` as live windows — the restore moves only
    /// windows that are in state, so a fixture that seeds
    /// `workspaces` alone would pass while proving nothing.
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

    // MARK: - The measurement

    /// A → B → A returns A's Spaces exactly as they were. This is
    /// the 2026-09-04 device round; reverting the restore reds it.
    @Test("A profile round trip restores its own partitioning")
    func roundTripIsLossless() {
        let core = makeCore()
        live(core, [1, 2, 3, 4, 5, 6, 7, 8])
        let a = profile("A", spaces: ["1", "2", "3"])
        let b = profile("B", spaces: ["1", "Work"])
        core.apply(profile: a, forceRetile: false)
        for id in [1, 2, 3, 4, 5] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: "1")
        }
        for id in [6, 7, 8] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: "3")
        }

        core.apply(profile: b, forceRetile: false)
        // Space 3 is not B's, so its windows forwarded — that half
        // is unchanged and deliberate.
        #expect(core.state.workspaces["3"] == nil)

        core.apply(profile: a, forceRetile: false)
        #expect(
            members(core, "1")
                == [1, 2, 3, 4, 5].map { WindowID(UInt32($0)) }
        )
        #expect(
            members(core, "3")
                == [6, 7, 8].map { WindowID(UInt32($0)) }
        )
    }

    /// The identity ruling: B's `1` is not A's `1`. A window put
    /// into B's `1` must not still be in A's `1` on the way back.
    @Test("Two profiles' same-named Spaces are different Spaces")
    func sameNameIsNotSameSpace() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")

        core.apply(profile: b, forceRetile: false)
        // In B, w2's Space does not exist, so it forwards into
        // B's own `1` alongside w1.
        #expect(members(core, "1") == [WindowID(1), WindowID(2)])

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }

    /// A window the incoming profile has never seen stays where
    /// the prune put it — its `fallback_space`. The ruled landing
    /// rule, and the reason the restore runs AFTER the prune.
    @Test("An unknown window lands in the profile's fallback")
    func unknownWindowLandsInFallback() {
        let core = makeCore()
        live(core, [1, 9])
        var b = profile("B", spaces: ["1", "Work"])
        b.fallbackSpace = "Work"
        let a = profile("A", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.apply(profile: b, forceRetile: false)
        // Opened while B was up, so A remembers nothing of it.
        core.state.workspaces.add(WindowID(9), to: "Work")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1").contains(WindowID(1)))
        // w9 has no home in A: it rehomed at the prune and the
        // restore left it there rather than inventing one.
        #expect(!members(core, "1").isEmpty)
        #expect(core.state.workspaces["Work"] == nil)
    }

    /// A re-apply of the LIVE profile is not a switch: nothing is
    /// filed and nothing is restored, so a monitor reconnect
    /// cannot revert the user's own moves.
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

    /// A remembered id whose window has gone is skipped, not
    /// inserted: a phantom in the row would outlive the window.
    @Test("A closed window is not restored")
    func closedWindowIsNotRestored() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")
        core.apply(profile: b, forceRetile: false)
        core.state.windows.remove(WindowID(2))
        core.state.workspaces.remove(WindowID(2))

        core.apply(profile: a, forceRetile: false)
        #expect(!members(core, "2").contains(WindowID(2)))
        #expect(!members(core, "1").contains(WindowID(2)))
    }

    /// A window away on another Desktop while the profile
    /// switches must not re-create the Space it left. `add`
    /// ensures its target, so without the guard the returning
    /// window leaks a Space into a profile that never declared
    /// one.
    @Test("A returning window does not re-create a dropped Space")
    func returningWindowDoesNotLeakASpace() {
        let core = makeCore()
        live(core, [1])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        // It departs for another Desktop, then the profile
        // switches while it is away — dropping Space "2".
        core.state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        core.apply(profile: b, forceRetile: false)
        #expect(core.state.workspaces["2"] == nil)

        // And now it comes back.
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A1")
            )
        )
        #expect(core.state.workspaces["2"] == nil)
        #expect(
            core.state.workspaces["1"]?.windows
                == [WindowID(1)]
        )
    }

    // MARK: - The enders

    @Test("A renamed profile keeps its partitioning")
    func renameFollowsThePartitioning() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.rename("A", to: "A2")
        #expect(store.remembered(for: "A") == nil)
        #expect(
            store.remembered(for: "A2")?["1"] == [WindowID(1)]
        )
    }

    @Test("A re-key moves the id in every profile's record")
    func rekeyReachesEveryProfile() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.rekey(WindowID(1), to: WindowID(77))
        #expect(
            store.remembered(for: "A")?["1"] == [WindowID(77)]
        )
    }

    @Test("Deleting a profile forgets its partitioning")
    func deleteForgets() {
        var store = ProfilePartitioning()
        store.adoptLive("A")
        store.record(
            [Space(id: "1", windows: [WindowID(1)])],
            handingLiveTo: "B"
        )
        store.forget("A")
        #expect(store.remembered(for: "A") == nil)
    }
}
