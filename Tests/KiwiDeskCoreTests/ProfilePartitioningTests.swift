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
///
/// WHICH applies count as a switch is
/// `ProfileSwitchClassificationTests`'; the enders are
/// `ProfilePartitioningEnderTests`'.
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

    /// The identity ruling: B's `1` is not A's `1`.
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
        #expect(members(core, "1") == [WindowID(1), WindowID(2)])

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }

    // MARK: - The landing rule

    /// A window the incoming profile has never seen stays where
    /// the prune put it. Where its Space is one the profile does
    /// NOT declare, that is the fallback — and the reason the
    /// restore runs after the prune.
    ///
    /// Scoped deliberately: the declared-Space case is the test
    /// below, and the title used to generalise past what this
    /// body exercises (docs review, 2026-09-04).
    @Test("An undeclared Space's window lands in the fallback")
    func unknownWindowLandsInFallback() {
        let core = makeCore()
        live(core, [1, 9])
        var b = profile("B", spaces: ["1", "Work"])
        b.fallbackSpace = "Work"
        let a = profile("A", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.apply(profile: b, forceRetile: false)
        // Opened while B was up, in a Space A does NOT declare.
        core.state.workspaces.add(WindowID(9), to: "Work")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1").contains(WindowID(1)))
        #expect(core.state.workspaces["Work"] == nil)
    }

    /// The other half: a window in a Space the incoming profile
    /// DOES declare stays put rather than being swept.
    @Test("A window in a declared Space is not swept")
    func declaredSpaceWindowStays() {
        let core = makeCore()
        live(core, [1, 9])
        var b = profile("B", spaces: ["1", "Work"])
        b.fallbackSpace = "Work"
        let a = profile("A", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(9), to: "1")

        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1").contains(WindowID(9)))
    }

    // MARK: - What a restore must not cost

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
    /// switches must not re-create the Space it left: `add`
    /// ensures its target, so the returning window would leak a
    /// Space into a profile that never declared one.
    @Test("A returning window does not re-create a dropped Space")
    func returningWindowDoesNotLeakASpace() {
        let core = makeCore()
        live(core, [1])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        core.state.apply(
            .windowDestroyed(WindowID(1), wasMinimized: false)
        )
        core.apply(profile: b, forceRetile: false)
        #expect(core.state.workspaces["2"] == nil)

        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "A1")
            )
        )
        #expect(core.state.workspaces["2"] == nil)
        #expect(
            core.state.workspaces["1"]?.windows == [WindowID(1)]
        )
    }

    /// The restore moves windows with `add`, whose `remove` half
    /// nils both focus trackers when the moved window holds them.
    /// Left uncorrected, every profile switch back whose set
    /// contains the focused window darkens the focus ring and the
    /// App Bar's focused item until the next AX report, and
    /// destroys the one-deep close-return candidate.
    @Test("A restore keeps the focus trackers")
    func restoreKeepsFocusTrackers() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")

        core.apply(profile: b, forceRetile: false)
        // In B the user moves w1 across and works in it, so it
        // holds the focus at the moment A's restore moves it
        // back — which is when `add`'s `remove` half would nil
        // the trackers.
        core.state.workspaces.add(WindowID(1), to: "2")
        core.state.workspaces.focus(WindowID(2), in: "2")
        core.state.workspaces.focus(WindowID(1), in: "2")
        #expect(core.state.workspaces.lastFocused == WindowID(1))

        core.apply(profile: a, forceRetile: false)
        #expect(core.state.workspaces.lastFocused == WindowID(1))
        #expect(
            core.state.workspaces.focusReturnCandidate
                == WindowID(2)
        )
    }

    /// A built-in Standard is not a profile. Going A → Standard
    /// → B must file A's OWN arrangement, not the one the
    /// Standard left on screen by the time B arrives.
    @Test("A Standard hands the live slot back")
    func standardDoesNotStealAProfilesRecord() {
        let core = makeCore()
        live(core, [1, 2])
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")

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
        // The Standard rearranges what is on screen.
        core.state.workspaces.add(WindowID(2), to: "1")

        core.apply(profile: b, forceRetile: false)
        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])
        #expect(members(core, "2") == [WindowID(2)])
    }
}
