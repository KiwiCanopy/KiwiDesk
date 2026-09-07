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

    /// Sends `id` to another Desktop: out of state, into the away
    /// ledger, with the `.departed` memory the return reads.
    private func sendAway(
        _ core: KiwiCore,
        _ id: WindowID,
        from space: SpaceID
    ) {
        core.state.rememberedSpaces[id] = .departed(space)
        core.state.awayWindows[id] = AwayWindow(
            id: id,
            pid: 1,
            appName: "App",
            appBundleID: nil,
            nativeSpace: SkyLight.SpaceID(9),
            isUp: true
        )
        core.state.workspaces.remove(id)
        core.state.windows.remove(id)
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
        sendAway(core, WindowID(1), from: "1")
        core.apply(profile: b, forceRetile: false)

        bringBack(core, WindowID(1))
        // B's own record wants it in Space 2.
        #expect(members(core, "2") == [WindowID(1)])
        #expect(members(core, "1").isEmpty)
    }
}
