import Foundation
import Testing

@testable import KiwiDeskCore

/// **The Space switch plates' Liquid Glass leaf is filled from the
/// switch's agreement** (#1956). A file below the floor carries no
/// `space_switch` leaf; absent, it decodes ON, so a user who had
/// the one Liquid Glass row off would open Settings to it reading
/// "differ" on a plain upgrade (profiles.md ▸ absence was a stored
/// value). Fixtures are the ENCODER's output with the leaf taken
/// out, never hand-written JSON, and the in-place clause reads the
/// TEXT, since a re-parse cannot tell an edit from a re-encode.
@Suite("Space switch glass migration (#1956)")
struct SpaceSwitchGlassMigrationTests {
    private static let group = "space_switch"
    private static let sources = [
        "kiwishelf", "shortcut_panel", "drag", "sticky",
    ]

    /// This build's settings as the encoder writes them, less the
    /// plates' leaf — or its whole group — with the four older
    /// leaves set as given.
    private static func settings(
        _ values: [Bool],
        dropGroup: Bool = false
    ) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var object = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(TilingSettings())
            ) as? [String: Any]
        )
        if dropGroup {
            object[group] = nil
        } else {
            var inner = try #require(object[group] as? [String: Any])
            try #require(inner["liquid_glass"] != nil)
            inner["liquid_glass"] = nil
            object[group] = inner
        }
        for (source, value) in zip(sources, values) {
            var inner = try #require(object[source] as? [String: Any])
            inner["liquid_glass"] = value
            object[source] = inner
        }
        return object
    }

    /// A profile root at the format before this step.
    private static func profile(_ settings: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.spaceSwitchGlassProfileFormat - 1,
                "monitor_sets": [], "name": "W", "settings": settings,
            ] as [String: Any],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func leaf(_ settings: Any?) -> Bool? {
        ((settings as? [String: Any])?[group] as? [String: Any])?[
            "liquid_glass"
        ] as? Bool
    }

    private static func leaf(of data: Data) throws -> Bool? {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return leaf(root["settings"])
    }

    @Test(
        "the leaf takes the switch's reading",
        arguments: [
            ([true, true, true, true], true),
            ([false, false, false, false], false),
            ([true, true, true, false], false),
            ([false, true, true, true], false),
        ]
    )
    func leafTakesTheAgreement(_ values: [Bool], _ expected: Bool) throws {
        let data = try Self.profile(Self.settings(values))
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try Self.leaf(of: out) == expected)
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(
                withJSONObject: try #require(root["settings"])
            )
        )
        #expect(decoded.spaceSwitchLiquidGlass == expected)
    }

    /// The edit only INSERTS: take the inserted leaf back out and
    /// the input remains, byte for byte.
    @Test(
        "the file is edited in place, group present or absent",
        arguments: [false, true]
    )
    func editIsInPlace(_ dropGroup: Bool) throws {
        let data = try Self.profile(
            Self.settings([false, false, false, false], dropGroup: dropGroup)
        )
        let text = try #require(String(data: data, encoding: .utf8))
        let out = try #require(
            ConfigMigration.migratingAbsentSpaceSwitchGlass(data)
        )
        let edited = try #require(String(data: out, encoding: .utf8))
        // The leaf goes in after the group's opener, or the whole
        // group after the settings opener; nothing else moves.
        let expected =
            dropGroup
            ? text.replacingOccurrences(
                of: #"("settings"\s*:\s*\{)"#,
                with: "$1\"space_switch\":{\"liquid_glass\":false},",
                options: .regularExpression
            )
            : text.replacingOccurrences(
                of: #"("space_switch"\s*:\s*\{)\s*\}"#,
                with: "$1\"liquid_glass\":false}",
                options: .regularExpression
            )
        #expect(expected != text)
        #expect(edited == expected, "the step re-encoded the file")
    }

    @Test("a bundle's profiles each take their own reading")
    func bundleProfilesAreEachTheirOwn() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.spaceSwitchGlassBundleFormat - 1,
                "writtenBy": "KiwiDesk",
                "profiles": [
                    [
                        "name": "On",
                        "settings": try Self.settings(
                            [true, true, true, true]
                        ),
                    ],
                    [
                        "name": "Off",
                        "settings": try Self.settings(
                            [false, false, false, false]
                        ),
                    ],
                ],
            ] as [String: Any]
        )
        // Through `migrated`: a bundle reaches the step only if its
        // format was bumped, which nothing else pins.
        let out = try #require(ConfigMigration.migrated(bundle))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        #expect(profiles.map { Self.leaf($0["settings"]) } == [true, false])
    }

    /// Not idempotent by construction — a leaf a user set is a
    /// stored value — so the step stands down AT its format.
    @Test("a file at the step's format is left alone")
    func currentFormatStandsDown() throws {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: Self.profile(
                    Self.settings([false, false, false, false])
                )
            ) as? [String: Any]
        )
        root["format"] = ConfigMigration.spaceSwitchGlassProfileFormat
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(ConfigMigration.migratingAbsentSpaceSwitchGlass(data) == nil)
    }

    /// The whole chain from before the drag and sticky leaves
    /// (#1620/#1621): this step reads them, so it runs after the
    /// step that fills them — an off switch reaches the plates.
    @Test("an off switch from before the overlay leaves reaches the plates")
    func runsAfterTheOverlayStep() throws {
        var settings = try Self.settings(
            [false, false, false, false],
            dropGroup: true
        )
        settings["drag"] = nil
        settings["sticky"] = nil
        let data = try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.overlayGlassProfileFormat - 1,
                "monitor_sets": [], "name": "Old", "settings": settings,
            ] as [String: Any]
        )
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try Self.leaf(of: out) == false)
    }
}
