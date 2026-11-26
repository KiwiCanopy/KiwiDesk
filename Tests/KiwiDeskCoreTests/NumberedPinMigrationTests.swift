import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile's pins leave its monitor sets for the profile itself,
/// keyed by screen number (#3647 ▸ Ruling), at both readers of the
/// shape: a profile file and a backup's `profiles[]`. Fixtures are
/// the encoder's output with each set's old `space_monitor_map`
/// put back and the format re-stamped.
@Suite("Numbered pin migration (#3647)")
struct NumberedPinMigrationTests {
    private let home = ["A:100x100", "B:100x100"]
    private let cowork = ["C:100x100", "D:100x100"]

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

    /// The old shape: per-set maps, no root map, `format` stamped.
    private func oldShape(
        _ root: inout [String: Any],
        format: Int,
        maps: [[String: String]]
    ) {
        var sets = root["monitor_sets"] as? [[String: Any]] ?? []
        for index in sets.indices {
            sets[index]["space_monitor_map"] = maps[index]
        }
        root["monitor_sets"] = sets
        root["space_monitor_map"] = nil
        root["format"] = format
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

    private var oldMaps: [[String: String]] {
        [
            ["2": "B:100x100", "3": "A:100x100#2"],
            ["2": "C:100x100", "4": "D:100x100"],
        ]
    }

    private var numbered: [SpaceID: ScreenSlotKey] {
        [
            "2": ScreenSlotKey(number: 2)!,
            "3": ScreenSlotKey(number: 1, areaID: 2)!,
            "4": ScreenSlotKey(number: 2)!,
        ]
    }

    @Test("a profile's pins cross onto numbers, the first set winning")
    func profileCrosses() throws {
        var root = try encoded(profile)
        oldShape(&root, format: 42, maps: oldMaps)
        let out = try #require(ConfigMigration.migrated(data(root)))
        let read = try JSONDecoder().decode(Profile.self, from: out)
        #expect(read.spaceMonitorMap == numbered)
        #expect(read.monitorSets.map(\.monitors) == [home, cowork])
        let raw = try #require(
            JSONSerialization.jsonObject(with: out) as? [String: Any]
        )
        let sets = raw["monitor_sets"] as? [[String: Any]] ?? []
        #expect(sets.allSatisfy { $0["space_monitor_map"] == nil })
    }

    @Test("a backup's profiles cross")
    func bundleCrosses() throws {
        let bundle = SetupBundle(
            format: 53,
            writtenBy: "test",
            config: GuiConfig(),
            profiles: [profile],
            palettes: []
        )
        var root = try encoded(bundle)
        var profiles = root["profiles"] as? [[String: Any]] ?? []
        oldShape(&profiles[0], format: 42, maps: oldMaps)
        root["profiles"] = profiles
        root["format"] = 53
        let out = try #require(ConfigMigration.migrated(data(root)))
        let read = try JSONDecoder().decode(SetupBundle.self, from: out)
        #expect(read.profiles.first?.spaceMonitorMap == numbered)
    }

    /// Twins share a fingerprint: the pin takes the lower number,
    /// the one the runtime places it on (#3647 ▸ Lane 1 rulings, 7).
    @Test("a twin's pin takes the lower number")
    func twinTakesTheLower() throws {
        let twins = ["T:100x100", "T:100x100"]
        let pair = Profile(
            name: "Twins",
            monitorSets: [MonitorSet(monitors: twins)],
            spaceModes: [:],
            settings: TilingSettings()
        )
        var root = try encoded(pair)
        oldShape(&root, format: 42, maps: [["1": "T:100x100"]])
        let out = try #require(ConfigMigration.migrated(data(root)))
        let read = try JSONDecoder().decode(Profile.self, from: out)
        #expect(read.spaceMonitorMap == ["1": ScreenSlotKey(number: 1)!])
    }

    /// The gate is the format, since the moved key keeps its name: a
    /// set-level map in a file at the new format is not crossed.
    @Test("a current file stays as it is")
    func currentFileStays() throws {
        var root = try encoded(profile)
        oldShape(&root, format: 43, maps: oldMaps)
        let current = try data(root)
        #expect(ConfigMigration.migratingPinsOntoNumbers(current) == nil)
        oldShape(&root, format: 42, maps: oldMaps)
        let old = try data(root)
        #expect(ConfigMigration.migratingPinsOntoNumbers(old) != nil)
    }

    @Test("a stored pin that is no number refuses the file")
    func strictDecode() throws {
        var root = try encoded(profile)
        root["space_monitor_map"] = ["1": "A:100x100"]
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Profile.self, from: data(root))
        }
    }
}
