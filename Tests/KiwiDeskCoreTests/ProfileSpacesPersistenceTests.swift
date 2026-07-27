import Foundation
import Testing

@testable import KiwiDeskCore

private func makeProfile(
    name: String,
    monitors: [String],
    pins: [SpaceID: String] = [:],
    mains: [SpaceID] = [],
    isDefault: Bool = false,
    modes: [SpaceID: LayoutMode] = ["1": .bsp]
) -> Profile {
    Profile(
        name: name,
        monitorSets: [
            MonitorSet(
                monitors: monitors,
                spaceMonitorMap: pins
            )
        ],
        mainSpaces: mains,
        isDefault: isDefault,
        spaceModes: modes,
        settings: TilingSettings(),
        // Whole seconds: profile files store ISO-8601 dates,
        // which drop sub-second precision.
        savedAt: Date(timeIntervalSince1970: 1_780_000_000)
    )
}

@Suite("Profile spaces & starter-ladder persistence")
struct ProfileSpacesPersistenceTests {
    // MARK: - spaces field (#75)

    @Test("Profile.spaces round-trips preserving order")
    func spacesRoundTrip() throws {
        // Parity test: the `spaces` field must survive a full
        // encode→decode cycle without re-sorting.
        let profile = Profile(
            name: "ordered",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaces: [
                SpaceID("c"), SpaceID("a"), SpaceID("b"),
            ],
            spaceModes: ["a": .stack],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            Profile.self,
            from: data
        )
        // Order must be c, a, b — not sorted alphabetically.
        #expect(
            decoded.spaces
                == [SpaceID("c"), SpaceID("a"), SpaceID("b")]
        )
    }

    @Test("Profile.spaces defaults to [] when key is absent")
    func spacesDecodeDefault() throws {
        // Parity test: legacy profiles without the `spaces`
        // key must decode without error and default to [].
        let json = """
            {"name":"old",
             "monitor_sets":[{"monitors":["A:1x1"]}],
             "space_modes":{},
             "settings":{},
             "saved_at":"2026-06-01T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(
            Profile.self,
            from: Data(json.utf8)
        )
        #expect(profile.spaces == [])
    }

    @Test("Profile JSON encodes a spaces key")
    func spacesKeyPresent() throws {
        // Round-trip sentinel: the encoded JSON must contain the
        // "spaces" key so stored profiles carry the order.
        let profile = Profile(
            name: "p",
            monitorSets: [MonitorSet(monitors: ["A:1x1"])],
            spaces: [SpaceID(1), SpaceID(2)],
            spaceModes: [:],
            settings: TilingSettings(),
            savedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(
            decoding: try encoder.encode(profile),
            as: UTF8.self
        )
        #expect(json.contains("\"spaces\":["))
    }

    @Test("starter_ladder flag round-trips (#485)")
    func starterLadderRoundTrips() throws {
        var profile = makeProfile(name: "s", monitors: ["A:1x1"])
        profile.isStarterLadder = true
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        #expect(
            String(decoding: data, as: UTF8.self)
                .contains("\"starter_ladder\":true")
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Profile.self, from: data)
        #expect(decoded.isStarterLadder)
    }

    @Test("starter_ladder defaults false when absent (#485)")
    func starterLadderDecodeDefault() throws {
        // Legacy profiles predate the key — they decode to false,
        // never the ladder baseline.
        let json = """
            {"name":"old",
             "monitor_sets":[{"monitors":["A:1x1"]}],
             "space_modes":{},
             "settings":{},
             "saved_at":"2026-06-01T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(
            Profile.self,
            from: Data(json.utf8)
        )
        #expect(!profile.isStarterLadder)
    }

    @Test("Profile.orderedSpaces uses stored order")
    func orderedSpacesUsesStoredOrder() {
        let profile = Profile(
            name: "p",
            monitorSets: [],
            spaces: [
                SpaceID("z"), SpaceID("a"), SpaceID("m"),
            ],
            spaceModes: [
                SpaceID("z"): .bsp,
                SpaceID("a"): .stack,
            ],
            settings: TilingSettings()
        )
        // Stored order "z, a, m" beats alphabetical "a, m, z".
        #expect(
            profile.orderedSpaces
                == [SpaceID("z"), SpaceID("a"), SpaceID("m")]
        )
    }

    @Test("Profile.orderedSpaces appends undeclared extras")
    func orderedSpacesAppendsExtras() {
        // A hand-edited profile may have a spaceModes key not in
        // the spaces list: orderedSpaces appends it at the end.
        let profile = Profile(
            name: "p",
            monitorSets: [],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [
                SpaceID("1"): .stack,
                SpaceID("3"): .grid,
            ],
            settings: TilingSettings()
        )
        let ordered = profile.orderedSpaces
        // "1" and "2" first (stored order); "3" appended.
        #expect(ordered.prefix(2) == [SpaceID("1"), SpaceID("2")])
        #expect(ordered.contains(SpaceID("3")))
    }
}
