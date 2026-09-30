import Foundation
import Testing

@testable import KiwiDeskCore

/// A composed Standard keeps its own #1230 record (#1829): it is
/// an arrangement like a saved profile, filed as it goes inactive
/// and restored when it returns — keyed apart from a profile of
/// the same name, since the docked Starter Standard and the saved
/// `Starter` profile share one.
@Suite("A composed Standard's own Space record (#1829)", .serialized)
@MainActor
struct StandardPartitioningTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("kiwi-standard-\(UUID().uuidString)")

    private func desk() throws -> (KiwiCore, Profile) {
        let core = makeTestCore(configDirectory: directory)
        for id in 1...2 {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "App\(id)"
                )
            )
        }
        let starter = Profile(
            name: "Starter",
            monitorSets: [],
            spaces: ["1", "2"],
            spaceModes: ["1": .bsp, "2": .bsp],
            settings: TilingSettings()
        )
        try core.profiles.write(starter)
        return (core, starter)
    }

    /// The Starter Standard: the same name as the saved profile.
    private let standard = ProfileComposition.Composed(
        sourceName: "Starter",
        spaces: ["1", "2"],
        spaceModes: ["1": .bsp, "2": .bsp],
        assignment: [:],
        settings: TilingSettings(),
        sourceTitle: nil
    )

    private func members(_ core: KiwiCore, _ space: SpaceID) -> [WindowID] {
        core.state.workspaces[space]?.windows ?? []
    }

    /// Docked into the Standard, rearranged; undocked into the
    /// profile of the same name; docked again: the Standard's
    /// arrangement comes back, not the profile's.
    @Test("A Standard gets its own arrangement back")
    func standardRestoresItsOwnArrangement() throws {
        let (core, starter) = try desk()
        core.apply(profile: starter, cause: .event)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.state.workspaces.add(WindowID(2), to: "2")

        core.apply(composed: standard, forceRetile: false)
        core.state.workspaces.add(WindowID(2), to: "1")

        core.apply(profile: starter, cause: .event)
        #expect(members(core, "2") == [WindowID(2)])

        core.apply(composed: standard, forceRetile: false)
        #expect(members(core, "1") == [WindowID(1), WindowID(2)])
        #expect(members(core, "2").isEmpty)
    }

    /// A reconnect re-composing the live Standard is no switch:
    /// its remembered lists are older than what is on screen.
    @Test("Re-applying the live Standard restores nothing")
    func reapplyIsNotASwitch() throws {
        let (core, starter) = try desk()
        core.apply(profile: starter, cause: .event)
        core.state.workspaces.add(WindowID(1), to: "1")
        core.apply(composed: standard, forceRetile: false)
        core.apply(profile: starter, cause: .event)
        core.apply(composed: standard, forceRetile: false)
        core.state.workspaces.add(WindowID(1), to: "2")

        core.apply(composed: standard, forceRetile: false)
        #expect(members(core, "2") == [WindowID(1)])
    }

    /// The Standard's record rides the snapshot beside the
    /// profiles', and boot adopts it although no file names it.
    @Test("A Standard's record survives a restart")
    func standardRecordSurvivesRestart() throws {
        let (first, starter) = try desk()
        first.apply(composed: standard, forceRetile: false)
        first.state.workspaces.add(WindowID(1), to: "2")
        first.apply(profile: starter, cause: .event)
        let session = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(first.sessionSnapshot())
        )
        #expect(session.standardRecords?.byProfile["Starter"] != nil)

        let (second, _) = try desk()
        second.apply(profile: starter, cause: .event)
        second.arrangeBootDesk(session: session)
        let key = HeldOrigin.Arrangement.standard("Starter")
        #expect(
            second.state.profilePartitioning.remembered(for: key)?["2"]
                == [WindowID(1)]
        )
    }
}
