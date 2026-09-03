import Foundation
import Testing

@testable import KiwiDeskCore

/// The `profile_bindings` string→object crossing (#1147).
///
/// The failure it guards is TOTAL, not silent: the decoder is
/// strict (AGENTS.md §5), so a `gui.json` from any earlier build
/// fails to decode as a UNIT — the user loses their Spaces, rules
/// and shortcuts along with the binding. A test that only checked
/// the binding would miss what the file costs.
@Suite("Profile binding migration (#1147)")
struct ProfileBindingMigrationTests {
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

    /// The key WAS the Mission Control number, so it is also the
    /// projection the migrated record carries.
    @Test("a string binding becomes an object keyed the same")
    func stringBecomesObject() throws {
        let data = json(
            #"{"format":1,"profile_bindings":{"2":"Work"}}"#
        )
        let out = try #require(ConfigMigration.migrated(data))
        let map = try bindings(out)
        let entry = try #require(map["2"] as? [String: Any])
        #expect(entry["profile"] as? String == "Work")
        #expect(entry["desktop"] as? Int == 2)
    }

    /// The whole file has to survive, not just the binding — that
    /// is what the strict decoder makes the stake.
    @Test("the rest of the file decodes after the crossing")
    func fileStillDecodes() throws {
        let data = json(
            """
            {"format":1,"spaces":["work","play"],\
            "float_rules":["Calculator"],\
            "profile_bindings":{"3":"Studio"}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let config = try JSONDecoder().decode(
            GuiConfig.self,
            from: out
        )
        #expect(config.spaces == [SpaceID("work"), SpaceID("play")])
        #expect(config.floatRules == ["Calculator"])
        #expect(
            config.profileBindings[.number(3)]
                == DesktopBinding(profile: "Studio", desktop: 3)
        )
    }

    /// A bundle carries `config` inline, so the walk has to reach
    /// a nested node — the second reader of this shape, and the
    /// one `ConfigMigrationRoutingTests` exists because of.
    @Test("the crossing reaches a binding inside a bundle")
    func reachesTheBundle() throws {
        let data = json(
            """
            {"format":3,"writtenBy":"0.9.7",\
            "config":{"profile_bindings":{"1":"Desk"}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let map = try bindings(out, at: ["config"])
        let entry = try #require(map["1"] as? [String: Any])
        #expect(entry["profile"] as? String == "Desk")
    }

    /// The STEP's own idempotence, called directly.
    ///
    /// Through `migrated` this is unreachable: a file at the
    /// current format short-circuits on `needsMigration` before
    /// any step runs, and a file below it is rewritten by the
    /// format stamp whatever the steps do. So the gate rescues
    /// the claim either way, and the step's own guard goes
    /// unguarded (`guard-prover`, 2026-09-04 — the
    /// rule-authoring.md "unrelated net" shape).
    @Test("the step rewrites nothing that is already an object")
    func stepIsIdempotent() {
        let already = json(
            #"{"profile_bindings":{"2":{"profile":"W","desktop":2}}}"#
        )
        #expect(
            ConfigMigration.migratingProfileBindingStrings(already)
                == nil
        )
    }

    /// And the gate above it: a file already at the current
    /// format is not rewritten at all, so its mtime never moves.
    @Test("a migrated file is not migrated again")
    func migrationEnds() throws {
        let data = json(
            """
            {"format":2,"profile_bindings":\
            {"2":{"profile":"Work","desktop":2}}}
            """
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }

    /// A key the old decoder could not read was DROPPED by it, so
    /// the crossing drops it too rather than inventing a Desktop
    /// for it.
    @Test("a non-numeric key is dropped, not invented")
    func nonNumericKeyDropped() throws {
        let data = json(
            #"{"format":1,"profile_bindings":{"x":"Work","2":"Ok"}}"#
        )
        let out = try #require(ConfigMigration.migrated(data))
        let map = try bindings(out)
        #expect(map["x"] == nil)
        #expect(map["2"] != nil)
    }
}
