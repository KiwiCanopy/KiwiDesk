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
}
