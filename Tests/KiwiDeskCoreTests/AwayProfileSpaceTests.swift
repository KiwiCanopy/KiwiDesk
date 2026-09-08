import Foundation
import Testing

@testable import KiwiDeskCore

/// A window away on another Desktop keeps the wrong Space across
/// a profile switch (#1248).
///
/// The away ledger and the per-profile partitioning (#1230) are
/// two authorities over one question — which Space a window
/// belongs to — and for an away window the ledger answers alone:
/// `restorePartitioning` skips a remembered id whose window is
/// not in state, correctly, and nothing else re-asserts the
/// incoming profile's placement.
@Suite("An away window follows the profile (#1248)", .serialized)
@MainActor
struct AwayProfileSpaceTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-awayprofile-\(UUID().uuidString)"
                )
        )
    }

    private func profile(
        _ name: String,
        spaces: [SpaceID]
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [],
            spaces: spaces,
            spaceModes: Dictionary(
                uniqueKeysWithValues: spaces.map { ($0, .bsp) }
            ),
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

    /// Sends `id` to another Desktop. The DESTROY FOLD does the
    /// departure, so the `.departed` memory and the #1207 rank are
    /// written the way production writes them — hand-filing the
    /// memory alone leaves `departedSlots` empty, and a fixture
    /// with no rank cannot see a rank being spent (code review,
    /// 2026-09-08). The ledger entry is the away half the
    /// compositor census would file.
    private func sendAway(_ core: KiwiCore, _ id: WindowID) {
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            id,
            wasMinimized: false,
            effects: &effects
        )
        core.state.awayWindows[id] = AwayWindow(
            id: id,
            pid: 1,
            appName: "App",
            appBundleID: nil,
            nativeSpace: SkyLight.SpaceID(9),
            isUp: true
        )
    }

    /// Brings it back, as the create fold does on arrival.
    private func bringBack(_ core: KiwiCore, _ id: WindowID) {
        var effects = AppliedEffects()
        core.state.applyWindowCreated(
            ManagedWindow(id: id, pid: 1, appName: "App"),
            effects: &effects
        )
    }

    private func members(
        _ core: KiwiCore,
        _ space: SpaceID
    ) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    /// The measured repro from the issue.
    @Test("A window away across a switch lands in B's Space")
    func awayWindowFollowsTheIncomingProfile() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1])

        // Under A, w1 sits in Space 1.
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        // Under B, the user moves it to Space 2, so B's
        // partitioning records it there when B goes inactive.
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1)])

        // It goes away to another Desktop, then the profile
        // switches to B while it is gone.
        sendAway(core, WindowID(1))
        core.apply(profile: b, forceRetile: false)

        // Re-filed to B's Space, and still a WATCHED departure:
        // the other kind is `.restored`, and promoting or
        // demoting one is invisible to a placement assertion.
        #expect(
            core.state.rememberedSpaces[WindowID(1)]
                == .departed("2")
        )

        bringBack(core, WindowID(1))
        // B's own record wants it in Space 2.
        #expect(members(core, "2") == [WindowID(1)])
        #expect(members(core, "1").isEmpty)
    }

    /// The other half: the outgoing record must not FORGET a
    /// window that is away. It recorded `workspaces.allSpaces`,
    /// and an away window is not in state, so every switch
    /// silently dropped whatever was on another Desktop.
    ///
    /// It takes A→B→A with the window away THROUGHOUT and the two
    /// profiles disagreeing about its Space. Simpler shapes do
    /// not discriminate: if the window's memory already names the
    /// Space its profile records, re-filing is a no-op and the
    /// record carrying it changes nothing (measured 2026-09-08 —
    /// the first draft of this test passed with the half
    /// reverted). Here B re-points the memory to Space 1 on the
    /// way out, so only A's own record can bring it back to 2.
    @Test("A profile's record keeps a window that is away")
    func theRecordKeepsAnAwayWindow() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1])

        // A puts w1 in Space 2; B puts it in Space 1.
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.apply(profile: a, forceRetile: false)
        #expect(members(core, "2") == [WindowID(1)])

        // Away it goes, and stays away across both switches.
        sendAway(core, WindowID(1))
        core.apply(profile: b, forceRetile: false)
        #expect(
            core.state.rememberedSpace(of: WindowID(1)) == "1",
            "B's record should have re-filed it to Space 1"
        )
        core.apply(profile: a, forceRetile: false)

        bringBack(core, WindowID(1))
        // Only A's record — taken while the window was away —
        // can carry it back to Space 2.
        #expect(members(core, "2") == [WindowID(1)])
        #expect(members(core, "1").isEmpty)
    }

    /// A redirect spends the #1207 return rank, because a rank
    /// means something only in the Space it was taken in. So a
    /// record naming the Space the window is ALREADY remembered
    /// in must not fire one — otherwise every away window loses
    /// its slot on every profile switch, and comes back last
    /// (code review, 2026-09-08).
    @Test("A same-Space record keeps the return rank")
    func aSameSpaceRecordKeepsTheRank() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1, 2, 3])

        core.apply(profile: a, forceRetile: false)
        for id in [1, 2, 3] {
            core.state.workspaces.add(WindowID(UInt32(id)), to: "1")
        }
        // The middle window leaves, so its rank is 1.
        sendAway(core, WindowID(2))
        let rank = core.state.departedSlots[WindowID(2)]
        #expect(rank != nil)

        // Both profiles record it in Space 1, so neither switch
        // has anything to re-point.
        core.apply(profile: b, forceRetile: false)
        core.apply(profile: a, forceRetile: false)
        #expect(core.state.departedSlots[WindowID(2)] == rank)

        bringBack(core, WindowID(2))
        #expect(
            members(core, "1")
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
    }

    /// A boot-seeded away window is filed `.restored`, not
    /// `.departed` — and a restart is the likeliest way to be
    /// away across a switch, so the re-file must reach it AND
    /// leave the kind alone.
    ///
    /// The kind is load-bearing elsewhere: `redirectDeparture`
    /// refuses anything but `.departed`, `rememberDepartedSlot`
    /// filters on it, and #1010's screen-home answers only for a
    /// departure the fold WATCHED. Promoting a boot filing into a
    /// watched departure, or demoting one, both shipped green
    /// (`guard-prover`, 2026-09-08).
    @Test("A restored filing is re-filed and stays restored")
    func aRestoredFilingKeepsItsKind() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1])

        // Give B a record placing w1 in Space 2.
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        core.apply(profile: a, forceRetile: false)

        // Now the boot-seed shape: away, filed `.restored` in
        // Space 1, with no watched departure behind it.
        core.state.windows.remove(WindowID(1))
        core.state.workspaces.remove(WindowID(1))
        core.state.remember(WindowID(1), in: "1")
        core.state.awayWindows[WindowID(1)] = AwayWindow(
            id: WindowID(1),
            pid: 1,
            appName: "App",
            appBundleID: nil,
            nativeSpace: SkyLight.SpaceID(9),
            isUp: true
        )

        core.apply(profile: b, forceRetile: false)
        #expect(
            core.state.rememberedSpaces[WindowID(1)]
                == .restored("2"),
            Comment(
                rawValue:
                    "B's record must re-file it, and a boot "
                    + "filing must not become a watched departure"
            )
        )
    }

    /// The mirror of the same-Space refusal: a REAL move drops
    /// the rank, because a rank means something only in the Space
    /// it was taken in. Keeping it shipped green — only the
    /// refusal direction was held (`guard-prover`, 2026-09-08).
    @Test("A cross-Space re-file drops the return rank")
    func aCrossSpaceRefileDropsTheRank() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1, 2])

        // B remembers w1 in Space 2; A leaves it in Space 1.
        core.apply(profile: b, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "1")
        sendAway(core, WindowID(1))
        #expect(core.state.departedSlots[WindowID(1)] != nil)

        // B re-files it into Space 2 — a different Space, so the
        // rank it took in Space 1 no longer means anything.
        core.apply(profile: b, forceRetile: false)
        #expect(
            core.state.rememberedSpace(of: WindowID(1)) == "2"
        )
        #expect(core.state.departedSlots[WindowID(1)] == nil)
    }

    /// A re-file re-points an EXISTING memory; it never mints
    /// one. A profile record can name a window whose memory has
    /// already been retired — `forgetAway` nils it on a census
    /// prune or an app exit — and a switch must not hand that
    /// window a departure nothing observed (`guard-prover`,
    /// 2026-09-08).
    @Test("A re-file mints no memory where none existed")
    func aRefileMintsNoMemory() {
        let core = makeCore()
        let a = profile("A", spaces: ["1", "2"])
        let b = profile("B", spaces: ["1", "2"])
        live(core, [1])

        core.apply(profile: a, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")
        // The switch captures A's record while w1 is still LIVE,
        // so the record names it. Only then does it go away and
        // have its memory retired outright — a census prune or an
        // app exit. A's record still names an id nothing has a
        // remembered Space for, which is the state the guard is
        // about, and it is unreachable if the memory is retired
        // before the record is taken (measured 2026-09-08).
        core.apply(profile: b, forceRetile: false)
        sendAway(core, WindowID(1))
        core.state.forgetAway(WindowID(1))
        #expect(
            core.state.rememberedSpaces[WindowID(1)] == nil
        )

        core.apply(profile: a, forceRetile: false)
        #expect(
            core.state.rememberedSpaces[WindowID(1)] == nil,
            "a profile switch minted a departure nothing observed"
        )
    }
}
