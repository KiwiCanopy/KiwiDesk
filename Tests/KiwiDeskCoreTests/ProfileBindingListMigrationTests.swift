import Foundation
import Testing

@testable import KiwiDeskCore

/// The `profile_bindings` `profile`→`profiles` crossing (#1436):
/// a record's one name becomes a list, its other keys — the
/// number, the #1438 screen — carried as they stand. The stake is
/// the FILE: the decoder is strict (AGENTS.md §5), so without the
/// step a format-2 gui.json fails to decode as a unit.
@Suite("Profile binding list migration (#1436)")
struct ProfileBindingListMigrationTests {
    private func json(_ raw: String) -> Data { Data(raw.utf8) }

    private func bindings(
        _ data: Data,
        at path: [String] = []
    ) throws -> [String: Any] {
        var node =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        for step in path { node = node?[step] as? [String: Any] }
        return try #require(
            node?["profile_bindings"] as? [String: Any]
        )
    }

    /// The format-2 shape a v1.3.0 build wrote, a stamp-keyed
    /// record with the screen #1438 added: the name lists, the
    /// rest rides.
    @Test("a single profile becomes a list, the rest carried")
    func profileBecomesList() throws {
        let data = json(
            """
            {"format":2,"spaces":["work"],"profile_bindings":\
            {"STAMP-A":{"profile":"Work","desktop":2,\
            "screen":"LG UltraFine"}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let entry = try #require(
            try bindings(out)["STAMP-A"] as? [String: Any]
        )
        #expect(entry["profiles"] as? [String] == ["Work"])
        #expect(entry["profile"] == nil)
        #expect(entry["desktop"] as? Int == 2)
        #expect(entry["screen"] as? String == "LG UltraFine")
        let config = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(config.spaces == [SpaceID("work")])
        #expect(
            config.profileBindings[
                .identity(DesktopIdentity(raw: "STAMP-A"))
            ]
                == DesktopBinding(
                    profiles: ["Work"],
                    desktop: 2,
                    screen: "LG UltraFine"
                )
        )
    }

    /// A format-1 file crosses #1147's step and this one in the
    /// same pass.
    @Test("a format-1 string binding crosses both steps")
    func formatOneCrossesBoth() throws {
        let data = json(
            #"{"format":1,"profile_bindings":{"2":"Work"}}"#
        )
        let out = try #require(ConfigMigration.migrated(data))
        let config = try JSONDecoder().decode(GuiConfig.self, from: out)
        #expect(
            config.profileBindings[.number(2)]
                == DesktopBinding(profiles: ["Work"], desktop: 2)
        )
    }

    /// A bundle carries `config` inline, so the walk reaches a
    /// nested node — `ConfigMigrationRoutingTests`' second reader.
    @Test("the crossing reaches a binding inside a bundle")
    func reachesTheBundle() throws {
        let data = json(
            """
            {"format":7,"writtenBy":"1.3.0",\
            "config":{"format":2,"profile_bindings":\
            {"1":{"profile":"Desk","desktop":1}}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let entry = try #require(
            try bindings(out, at: ["config"])["1"] as? [String: Any]
        )
        #expect(entry["profiles"] as? [String] == ["Desk"])
    }

    /// The STEP's own idempotence, called directly — through
    /// `migrated` the format gate rescues the claim either way.
    @Test("the step rewrites nothing already listed")
    func stepIsIdempotent() {
        let already = json(
            #"{"profile_bindings":{"2":{"profiles":["W"],"desktop":2}}}"#
        )
        #expect(
            ConfigMigration.migratingProfileBindingLists(already) == nil
        )
    }

    /// The stamp is DERIVED, never spelled (tests.md ▸ #1021).
    @Test("a migrated file is not migrated again")
    func migrationEnds() throws {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),\
            "profile_bindings":\
            {"2":{"profiles":["Work"],"desktop":2}}}
            """
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }
}
