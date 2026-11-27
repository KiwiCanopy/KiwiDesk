import Foundation
import Testing

@testable import KiwiDeskCore

/// A split keyed by a screen's fingerprint in points crosses onto
/// the profile's screen numbers as per-mille shares (#3647 ▸ lane
/// 3), at every reader of the shape: a profile file and a backup's
/// `profiles[]` (`gui.json` stores no `settings`), each through
/// `ConfigMigration.migrated` from the format the last release
/// shipped. Fixtures are the encoder's output with the old
/// `display_areas` put back and the format re-stamped.
@Suite("Numbered split migration (#3647)")
struct NumberedSplitMigrationTests {
    private let home = ["A:2000x1000", "B:1000x1000"]
    private let cowork = ["C:1000x500", "A:2000x1000"]

    /// A split of the `width`-wide screen into two halves, in the
    /// old points shape.
    private func halves(_ width: Int, _ height: Int) throws -> Any {
        let split = try #require(
            ScreenSplit.whole(width: width, height: height)
                .splitting(0, .sideBySide)
        )
        return try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(split)
        )
    }

    private var expectedHalves: ScreenShares {
        ScreenShares(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 500, h: 1000),
                ScreenArea(id: 1, x: 500, y: 0, w: 500, h: 1000),
            ],
            nextID: 2
        )
    }

    private func encoded(_ value: some Encodable) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(value)
            ) as? [String: Any]
        )
    }

    private func data(_ root: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func oldSplits(
        _ owner: inout [String: Any],
        _ splits: [String: Any]
    ) {
        var settings = owner["settings"] as? [String: Any] ?? [:]
        settings["display_areas"] = splits
        owner["settings"] = settings
    }

    private var profile: Profile {
        Profile(
            name: "Work",
            monitorSets: [
                MonitorSet(monitors: home),
                MonitorSet(monitors: cowork),
            ],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("a profile's splits cross onto numbers, the first set winning")
    func profileCrosses() throws {
        var root = try encoded(profile)
        oldSplits(
            &root,
            [
                "A:2000x1000": try halves(2000, 1000),
                "C:1000x500": try halves(1000, 500),
                "Gone:1x1": try halves(1000, 1000),
            ]
        )
        root["format"] = 43
        let out = try #require(ConfigMigration.migrated(data(root)))
        let read = try JSONDecoder().decode(Profile.self, from: out)
        // A is Screen 1 in the first set; C's 1 in the second loses.
        #expect(read.settings.displayAreas == ["1": expectedHalves])
    }

    @Test("a backup's profiles cross")
    func bundleCrosses() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var bundle = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(
                    SetupBundle(
                        writtenBy: "test",
                        config: GuiConfig(),
                        profiles: [profile],
                        palettes: []
                    )
                )
            ) as? [String: Any]
        )
        var profiles = try #require(
            bundle["profiles"] as? [[String: Any]]
        )
        oldSplits(&profiles[0], ["B:1000x1000": try halves(1000, 1000)])
        bundle["profiles"] = profiles
        bundle["format"] = 55
        let out = try #require(ConfigMigration.migrated(data(bundle)))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try decoder.decode(SetupBundle.self, from: out)
        // B is Screen 2 in the profile's first set.
        #expect(
            read.profiles.first?.settings.displayAreas
                == ["2": expectedHalves]
        )
    }

    @Test("the step stands down at the format it introduced")
    func stepIsIdempotent() throws {
        var root = try encoded(profile)
        oldSplits(&root, ["A:2000x1000": try halves(2000, 1000)])
        root["format"] = ConfigMigration.numberedSplitsProfileFormat
        let current = try data(root)
        #expect(ConfigMigration.migratingSplitsOntoNumbers(current) == nil)
        root["format"] = 43
        let older = try data(root)
        #expect(ConfigMigration.migratingSplitsOntoNumbers(older) != nil)
    }

    /// A backup already at the floor holds number keys no set
    /// holds; a second run would drop every split in it.
    @Test("the step stands down for a backup at its format")
    func bundleStepIsIdempotent() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var bundle = try #require(
            JSONSerialization.jsonObject(
                with: encoder.encode(
                    SetupBundle(
                        writtenBy: "test",
                        config: GuiConfig(),
                        profiles: [profile],
                        palettes: []
                    )
                )
            ) as? [String: Any]
        )
        var profiles = try #require(
            bundle["profiles"] as? [[String: Any]]
        )
        oldSplits(&profiles[0], ["B:1000x1000": try halves(1000, 1000)])
        bundle["profiles"] = profiles
        bundle["format"] = ConfigMigration.numberedSplitsBundleFormat
        let current = try data(bundle)
        #expect(ConfigMigration.migratingSplitsOntoNumbers(current) == nil)
        bundle["format"] = 55
        let older = try data(bundle)
        #expect(ConfigMigration.migratingSplitsOntoNumbers(older) != nil)
    }
}
