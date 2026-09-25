import Foundation
import Testing

@testable import KiwiDeskCore

/// **The drag markers' and sticky mark's Liquid Glass leaves are
/// filled from the switch's agreement** (#1620/#1621). A file below
/// the floor carries neither; absent, both decode ON, so a user who
/// had the one Liquid Glass row off would open Settings to it
/// reading "differ" on a plain upgrade (profiles.md ▸ absence was a
/// stored value).
///
/// Fixtures are the ENCODER's output with the two leaves taken out,
/// never hand-written JSON (a hand fixture proves a step against
/// itself), and the in-place clauses read the TEXT, since a re-parse
/// cannot tell an edit from a re-encode.
@Suite("Drag and sticky glass migration (#1620, #1621)")
struct GlassOverlayMigrationTests {
    private static let groups = ["drag", "sticky"]

    /// This build's settings as the encoder writes them, less the
    /// two leaves, with the shelf's and panel's set as given.
    private static func settings(
        shelf: Bool,
        panel: Bool,
        dropGroups: Bool = false
    ) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var object = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(TilingSettings())
            ) as? [String: Any]
        )
        for group in groups {
            if dropGroups {
                object[group] = nil
                continue
            }
            var inner = try #require(object[group] as? [String: Any])
            try #require(inner["liquid_glass"] != nil, "\(group)")
            inner["liquid_glass"] = nil
            object[group] = inner
        }
        for (group, value) in [
            ("kiwishelf", shelf), ("shortcut_panel", panel),
        ] {
            var inner = try #require(object[group] as? [String: Any])
            inner["liquid_glass"] = value
            object[group] = inner
        }
        return object
    }

    /// A profile root at the format before this step.
    private static func profile(_ settings: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": 8, "monitor_sets": [], "name": "W",
                "settings": settings,
            ] as [String: Any],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// The two leaves a migrated settings object carries.
    private static func leaves(_ data: Data) throws -> [Bool?] {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        return groups.map {
            ($0 == "drag" ? settings["drag"] : settings["sticky"])
                .flatMap { $0 as? [String: Any] }?["liquid_glass"] as? Bool
        }
    }

    @Test(
        "each leaf takes the switch's reading",
        arguments: [
            (true, true, true), (false, false, false),
            (true, false, false), (false, true, false),
        ]
    )
    func leavesTakeTheAgreement(
        _ shelf: Bool,
        _ panel: Bool,
        _ expected: Bool
    ) throws {
        let data = try Self.profile(
            Self.settings(shelf: shelf, panel: panel)
        )
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try Self.leaves(out) == [expected, expected])
        // And the decoded settings agree with the file.
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(
                withJSONObject: try #require(root["settings"])
            )
        )
        #expect(decoded.dragLiquidGlass == expected)
        #expect(decoded.stickyStyle.liquidGlass == expected)
    }

    /// The edit only INSERTS: take the inserted leaves back out and
    /// the input remains, byte for byte — no re-encoded Double, no
    /// reordered key.
    @Test(
        "the file is edited in place, groups present or absent",
        arguments: [false, true]
    )
    func editIsInPlace(_ dropGroups: Bool) throws {
        let data = try Self.profile(
            Self.settings(shelf: false, panel: false, dropGroups: dropGroups)
        )
        let text = try #require(String(data: data, encoding: .utf8))
        let out = try #require(
            ConfigMigration.migratingAbsentOverlayGlass(data)
        )
        var edited = try #require(String(data: out, encoding: .utf8))
        let inserted =
            dropGroups
            ? [
                "\"drag\":{\"liquid_glass\":false},"
                    + "\"sticky\":{\"liquid_glass\":false},"
            ]
            : ["\"liquid_glass\":false,"]
        for piece in inserted {
            try #require(edited.contains(piece), "no \(piece)")
            edited = edited.replacingOccurrences(of: piece, with: "")
        }
        #expect(edited == text, "the step re-encoded the file")
    }

    /// Two profiles in one bundle that read the switch differently
    /// each keep their own answer — the edit stands down to the
    /// walk, which asks per settings object.
    @Test("a bundle's profiles each take their own reading")
    func bundleProfilesAreEachTheirOwn() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": 12, "writtenBy": "KiwiDesk",
                "profiles": [
                    [
                        "name": "On",
                        "settings": try Self.settings(
                            shelf: true,
                            panel: true
                        ),
                    ],
                    [
                        "name": "Off",
                        "settings": try Self.settings(
                            shelf: false,
                            panel: false
                        ),
                    ],
                ],
            ] as [String: Any]
        )
        let out = try #require(
            ConfigMigration.migratingAbsentOverlayGlass(bundle)
        )
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let read = profiles.map { profile in
            ((profile["settings"] as? [String: Any])?["drag"]
                as? [String: Any])?["liquid_glass"] as? Bool
        }
        #expect(read == [true, false])
    }

    /// Not idempotent by construction — a leaf a user set is a
    /// stored value — so the step stands down AT the format it
    /// introduced. A direct call, since `migrated`'s own gate would
    /// rescue a current file and prove nothing about the step.
    @Test("a file at the step's format is left alone")
    func currentFormatStandsDown() throws {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: Self.profile(Self.settings(shelf: false, panel: false))
            ) as? [String: Any]
        )
        root["format"] = ConfigMigration.overlayGlassProfileFormat
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingAbsentOverlayGlass(data) == nil)
    }
}
