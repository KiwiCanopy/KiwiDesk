import Foundation
import Testing

@testable import KiwiDeskCore

/// #1230's per-profile record survives a KiwiDesk restart
/// (#1802): the session snapshot carries every profile's record,
/// and boot adopts it after the replay, so a profile that was not
/// live at the quit still gets its windows back when it returns.
@Suite("Per-profile Space records across a restart (#1802)", .serialized)
@MainActor
struct ProfilePartitioningRestartTests {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("kiwi-partition-\(UUID().uuidString)")

    private func makeCore() -> KiwiCore {
        makeTestCore(configDirectory: directory)
    }

    private func profile(_ name: String, _ spaces: [SpaceID]) -> Profile {
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

    private let dual = SpaceID("3")

    /// Two saved profiles, eight live windows, `A` applied — the
    /// fixture both processes of a restart build.
    private func desk() throws -> (KiwiCore, Profile, Profile) {
        let core = makeCore()
        for id in 1...8 {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: 1,
                    appName: "App\(id)"
                )
            )
        }
        let a = profile("A", ["1", "2", dual])
        let b = profile("B", ["1", "Work"])
        try core.profiles.write(a)
        try core.profiles.write(b)
        return (core, a, b)
    }

    private var arranged: [WindowID] { [6, 7, 8].map(WindowID.init) }

    /// The file the quit writes, read back as the next boot does.
    private func throughTheFile(_ snapshot: StateSnapshot) throws
        -> StateSnapshot
    {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
    }

    /// The issue's steps: A goes inactive holding Space 3, the
    /// process restarts under B, and A comes back.
    @Test("A profile not live at the quit gets its windows back")
    func recordSurvivesRestart() throws {
        let (first, a, b) = try desk()
        first.apply(profile: a, cause: .event)
        for id in arranged { first.state.workspaces.add(id, to: dual) }
        first.apply(profile: b, cause: .event)
        let session = try throughTheFile(first.sessionSnapshot())

        let (second, _, _) = try desk()
        second.apply(profile: b, cause: .event)
        second.arrangeBootDesk(session: session)
        #expect(second.state.profilePartitioning.hasRecord(for: "A"))

        second.apply(profile: a, cause: .event)
        #expect(second.state.workspaces[dual]?.windows == arranged)
    }

    /// Quit under A, relaunch under B: A was LIVE at the quit, so
    /// its record is filed fresh into the capture rather than
    /// whatever it left the last time it went inactive.
    @Test("The profile live at the quit is carried as it stood")
    func liveProfileIsFiledAtCapture() throws {
        let (core, a, _) = try desk()
        core.apply(profile: a, cause: .event)
        for id in arranged { core.state.workspaces.add(id, to: dual) }

        let records = core.sessionSnapshot().profileRecords?.records
        #expect(records?["A"]?[dual] == arranged)
        // A copy: the live record is written only at a switch.
        #expect(!core.state.profilePartitioning.hasRecord(for: "A"))
    }

    /// Anything this session filed before the replay reflects the
    /// scan's order, not the user's arrangement: the carried
    /// record replaces it.
    @Test("A carried record outranks one filed during the scan")
    func carriedRecordWins() throws {
        let (first, a, b) = try desk()
        first.apply(profile: a, cause: .event)
        for id in arranged { first.state.workspaces.add(id, to: dual) }
        first.apply(profile: b, cause: .event)
        let session = try throughTheFile(first.sessionSnapshot())

        let (second, _, _) = try desk()
        second.apply(profile: b, cause: .event)
        second.state.profilePartitioning.record(
            [Space(id: dual, windows: [WindowID(1)])],
            as: "A"
        )
        second.arrangeBootDesk(session: session)
        #expect(
            second.state.profilePartitioning.remembered(for: "A")?[dual]
                == arranged
        )
    }

    /// A record whose profile left the disk while KiwiDesk was
    /// down could never be restored, and a new profile of that
    /// name is not it.
    @Test("A deleted profile's record is not adopted")
    func deletedProfileIsDropped() throws {
        let (core, _, b) = try desk()
        core.apply(profile: b, cause: .event)
        var session = core.sessionSnapshot()
        session.profileRecords = StateSnapshot.ProfileRecords(
            ["Gone": [dual: arranged], "A": [dual: arranged]]
        )
        core.arrangeBootDesk(session: session)
        #expect(!core.state.profilePartitioning.hasRecord(for: "Gone"))
        #expect(core.state.profilePartitioning.hasRecord(for: "A"))
    }

    /// Each profile's entry decodes on its own, and the field on
    /// its own: an unreadable record costs only itself.
    @Test("An unreadable record costs only itself")
    func unreadableRecordIsIsolated() throws {
        let entry = #"{"A":{"3":[6,7,8]},"B":"garbage"}"#
        let partial = try decode(records: entry)
        #expect(partial.profileRecords?.records["A"]?[dual] == arranged)
        #expect(partial.profileRecords?.byProfile["B"] == nil)
        #expect(partial.spaces.count == 1)

        // Two keys naming one Space: damaged, and still no trap.
        let twin = try decode(records: #"{"A":{"3":[6],"03":[7]}}"#)
        #expect(twin.profileRecords?.records["A"]?.count == 1)

        let broken = try decode(records: #""garbage""#)
        #expect(broken.profileRecords == nil)
        #expect(broken.spaces.count == 1)
    }

    private func decode(records: String) throws -> StateSnapshot {
        let json = """
            {"windows":[],"capturedAt":0,"activeSpace":"1",
             "spaces":[{"id":"1","mode":"bsp","windows":[]}],
             "profileRecords":\(records)}
            """
        return try JSONDecoder().decode(
            StateSnapshot.self,
            from: Data(json.utf8)
        )
    }
}
