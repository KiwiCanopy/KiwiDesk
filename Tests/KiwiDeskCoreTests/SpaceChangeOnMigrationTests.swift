import Foundation
import Testing

@testable import KiwiDeskCore

/// **A stored `on_space_change: false` from before 2.2.0 is turned
/// on once** (#1931): the leaf used to slide the windows themselves
/// and now plays the plate slide, so the stored value answered
/// another question (profiles.md ▸ a value whose meaning changes).
/// A group whose other master leaves are all off is the master
/// switched off and keeps its `false`. Fixtures are the ENCODER's
/// output, never hand-written JSON, and the in-place clause reads
/// the TEXT, since a re-parse cannot tell an edit from a re-encode.
@Suite("Space switch slide turned on (#1931)")
struct SpaceChangeOnMigrationTests {
    private static let leaf = "on_space_change"
    private static let masterLeaves = [
        "on_window_resize", "on_window_swap", "on_relayout",
    ]

    /// This build's settings as the encoder writes them, the slide
    /// off and the master's other leaves set as given.
    private static func settings(
        slide: Bool = false,
        master: [Bool] = [true, true, true]
    ) throws -> [String: Any] {
        var settings = TilingSettings()
        settings.animations.onSpaceChange = slide
        settings.animations.onWindowResize = master[0]
        settings.animations.onWindowSwap = master[1]
        settings.animations.onRelayout = master[2]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try #require(
            JSONSerialization.jsonObject(with: encoder.encode(settings))
                as? [String: Any]
        )
    }

    /// A profile root at `format`, the one before this step's by
    /// default.
    private static func profile(
        _ settings: [String: Any],
        format: Int = ConfigMigration.spaceChangeOnProfileFormat - 1
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [], "name": "P", "settings": settings,
            ] as [String: Any],
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func slide(_ settings: Any?) -> Bool? {
        ((settings as? [String: Any])?["animations"] as? [String: Any])?[
            leaf
        ] as? Bool
    }

    private static func slide(of data: Data) throws -> Bool? {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        return slide(root["settings"])
    }

    @Test(
        "an old off turns on unless the master reads off",
        arguments: [
            ([true, true, true], true),
            ([false, false, true], true),
            ([true, false, false], true),
            ([false, false, false], false),
        ]
    )
    func offTurnsOn(_ master: [Bool], _ expected: Bool) throws {
        let data = try Self.profile(Self.settings(master: master))
        let out = try #require(ConfigMigration.migrated(data))
        #expect(try Self.slide(of: out) == expected)
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(
                withJSONObject: try #require(root["settings"])
            )
        )
        #expect(decoded.animations.onSpaceChange == expected)
    }

    @Test("a stored on is left as it is")
    func onStaysOn() throws {
        let data = try Self.profile(Self.settings(slide: true))
        #expect(ConfigMigration.migratingSpaceChangeOn(data) == nil)
    }

    /// The edit changes the one literal: the input with that
    /// `false` read as `true` is the output, byte for byte.
    @Test("the file is edited in place")
    func editIsInPlace() throws {
        let data = try Self.profile(Self.settings())
        let text = try #require(String(data: data, encoding: .utf8))
        let out = try #require(ConfigMigration.migratingSpaceChangeOn(data))
        let edited = try #require(String(data: out, encoding: .utf8))
        let expected = text.replacingOccurrences(
            of: #"("on_space_change"\s*:\s*)false"#,
            with: "$1true",
            options: .regularExpression
        )
        #expect(expected != text)
        #expect(edited == expected, "the step re-encoded the file")
    }

    /// One bundle, two readings: the edit must turn on only the
    /// profile the walk turns on, or the envelope falls back to a
    /// re-encode — the in-place clause holds that it did not.
    @Test("a bundle's profiles each take their own reading")
    func bundleProfilesAreEachTheirOwn() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.spaceChangeOnBundleFormat - 1,
                "writtenBy": "KiwiDesk",
                "profiles": [
                    ["name": "On", "settings": try Self.settings()],
                    [
                        "name": "Still",
                        "settings": try Self.settings(
                            master: [false, false, false]
                        ),
                    ],
                ],
            ] as [String: Any],
            options: [.prettyPrinted, .sortedKeys]
        )
        let step = try #require(
            ConfigMigration.migratingSpaceChangeOn(bundle)
        )
        let text = try #require(String(data: bundle, encoding: .utf8))
        let edited = try #require(String(data: step, encoding: .utf8))
        #expect(
            edited.components(separatedBy: "\n").count
                == text.components(separatedBy: "\n").count
        )
        // Through `migrated`: a bundle reaches the step only if its
        // format was bumped, which nothing else pins.
        let out = try #require(ConfigMigration.migrated(bundle))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        #expect(
            profiles.map { Self.slide($0["settings"]) } == [true, false]
        )
    }

    /// Not idempotent by construction — a `true` turned on is the
    /// same bytes as one chosen — so the step stands down AT its
    /// format, and a `false` chosen after the crossing stays.
    @Test("a file at the step's format is left alone")
    func stepStandsDownAtItsFormat() throws {
        let profile = try Self.profile(
            Self.settings(),
            format: ConfigMigration.spaceChangeOnProfileFormat
        )
        #expect(ConfigMigration.migratingSpaceChangeOn(profile) == nil)
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.spaceChangeOnBundleFormat,
                "writtenBy": "KiwiDesk",
                "profiles": [
                    ["name": "P", "settings": try Self.settings()]
                ],
            ] as [String: Any]
        )
        #expect(ConfigMigration.migratingSpaceChangeOn(bundle) == nil)
    }

    /// The step ends the crossing for every file this build writes:
    /// a profile saved now carries the format the step stands down
    /// at.
    @Test("a profile written now is at the step's format")
    func writerStampsTheFloor() {
        #expect(
            Profile.currentFormat
                >= ConfigMigration.spaceChangeOnProfileFormat
        )
        #expect(
            SetupBundle.currentFormat
                >= ConfigMigration.spaceChangeOnBundleFormat
        )
    }
}
