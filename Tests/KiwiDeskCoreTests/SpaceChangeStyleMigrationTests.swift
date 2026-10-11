import Foundation
import Testing

@testable import KiwiDeskCore

/// **A stored `on_space_change` crosses onto `space_change` once**
/// (#2143): `true` names the Space (the whole-written default, as
/// #1931 argued), `false` is Instant. Fixtures are the ENCODER's
/// values with the 2.x leaf put back, laid out COMPACT — a shape
/// the fallback's pretty, sorted re-encode never writes — so the
/// in-place clause, which reads the TEXT, can tell an edit from a
/// re-encode.
@Suite("Space switch style crossing (#2143)")
struct SpaceChangeStyleMigrationTests {
    private static let leaf = "on_space_change"

    /// This build's settings, the style replaced by the 2.x leaf.
    private static func settings(slide: Bool) throws -> [String: Any] {
        var root = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(TilingSettings())
            ) as? [String: Any]
        )
        var group = try #require(root["animations"] as? [String: Any])
        group[ConfigMigration.spaceChangeStyleKey] = nil
        group[leaf] = slide
        root["animations"] = group
        return root
    }

    /// A profile root at `format`, the one before this step's by
    /// default — past #1931's, so its turn-on stays out.
    private static func profile(
        slide: Bool,
        format: Int = ConfigMigration.spaceChangeStyleProfileFormat - 1
    ) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [
                "format": format,
                "monitor_sets": [], "name": "P",
                "settings": try settings(slide: slide),
            ] as [String: Any]
        )
    }

    private static func style(ofSettings settings: Any?) -> String? {
        ((settings as? [String: Any])?["animations"] as? [String: Any])?[
            ConfigMigration.spaceChangeStyleKey
        ] as? String
    }

    @Test(
        "on becomes the Space cue, off becomes Instant",
        arguments: [(true, SpaceChangeStyle.cue), (false, .instant)]
    )
    func crossesEachValue(_ slide: Bool, _ expected: SpaceChangeStyle) throws {
        let out = try #require(
            ConfigMigration.migrated(try Self.profile(slide: slide))
        )
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        let group = try #require(settings["animations"] as? [String: Any])
        #expect(group[Self.leaf] == nil)
        let decoded = try JSONDecoder().decode(
            TilingSettings.self,
            from: JSONSerialization.data(withJSONObject: settings)
        )
        #expect(decoded.animations.spaceChange == expected)
    }

    /// The edit changes the one pair: the input with that leaf
    /// spelled as the style is the output, byte for byte.
    @Test("the file is edited in place")
    func editIsInPlace() throws {
        let data = try Self.profile(slide: false)
        let text = try #require(String(data: data, encoding: .utf8))
        let out = try #require(
            ConfigMigration.migratingSpaceChangeStyle(data)
        )
        let edited = try #require(String(data: out, encoding: .utf8))
        let expected = text.replacingOccurrences(
            of: #""on_space_change"(\s*:\s*)false"#,
            with: #""space_change"$1"instant""#,
            options: .regularExpression
        )
        #expect(expected != text)
        #expect(edited == expected, "the step re-encoded the file")
    }

    @Test("a bundle's profiles each cross on their own value")
    func bundleProfilesCross() throws {
        let bundle = try JSONSerialization.data(
            withJSONObject: [
                "format": ConfigMigration.spaceChangeStyleBundleFormat - 1,
                "writtenBy": "KiwiDesk",
                "profiles": [
                    [
                        "name": "On",
                        "settings": try Self.settings(slide: true),
                    ],
                    [
                        "name": "Off",
                        "settings": try Self.settings(slide: false),
                    ],
                ],
            ] as [String: Any]
        )
        let out = try #require(ConfigMigration.migrated(bundle))
        let root = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        #expect(
            profiles.map { Self.style(ofSettings: $0["settings"]) }
                == ["cue", "instant"]
        )
    }

    @Test("a file at the step's format is left alone")
    func stepStandsDownAtItsFormat() throws {
        let data = try Self.profile(
            slide: false,
            format: ConfigMigration.spaceChangeStyleProfileFormat
        )
        #expect(ConfigMigration.migratingSpaceChangeStyle(data) == nil)
    }

    @Test("a profile written now is at the step's format")
    func writerStampsTheFloor() {
        #expect(
            Profile.currentFormat
                >= ConfigMigration.spaceChangeStyleProfileFormat
        )
        #expect(
            SetupBundle.currentFormat
                >= ConfigMigration.spaceChangeStyleBundleFormat
        )
    }
}
