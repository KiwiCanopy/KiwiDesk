import CoreGraphics
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

@Suite("Profile data model")
struct ProfileModelTests {
    @Test("Monitor sets store canonically sorted")
    func sortedMonitors() {
        let set = MonitorSet(monitors: ["B:2x2", "A:1x1"])
        #expect(set.monitors == ["A:1x1", "B:2x2"])
    }

    @Test("Pins to monitors outside the set are dropped")
    func orphanPinsDropped() {
        let set = MonitorSet(
            monitors: ["A:1x1"],
            spaceMonitorMap: [
                SpaceID(1): "A:1x1",
                SpaceID(2): "GONE:9x9",
            ]
        )
        #expect(
            set.spaceMonitorMap == [SpaceID(1): "A:1x1"]
        )
    }

    @Test("Mismatched set lengths drop; first is canonical")
    func setLengthSanitization() {
        let profile = Profile(
            name: "p",
            monitorSets: [
                MonitorSet(monitors: ["A:1x1", "B:2x2"]),
                MonitorSet(monitors: ["C:3x3"]),
                MonitorSet(monitors: ["D:4x4", "E:5x5"]),
            ],
            spaceModes: [:],
            settings: TilingSettings()
        )
        #expect(profile.monitorSets.count == 2)
        #expect(profile.monitorCount == 2)
    }

    @Test("A profile with zero valid sets fails to decode")
    func zeroSetsInvalid() throws {
        let json = """
            {"name": "broken", "monitor_sets": [],
             "space_modes": {}, "settings": {},
             "saved_at": "2026-06-01T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: DecodingError.self) {
            try decoder.decode(
                Profile.self,
                from: Data(json.utf8)
            )
        }
    }

    @Test("Identical monitors do not collapse (multiset)")
    func duplicateMonitors() {
        let dual = makeProfile(
            name: "dual",
            monitors: ["LG:2560x1440", "LG:2560x1440"]
        )
        // The old Set comparison collapsed the twins, so a
        // single LG wrongly matched the dual profile.
        #expect(dual.set(matching: ["LG:2560x1440"]) == nil)
        #expect(
            dual.set(
                matching: ["LG:2560x1440", "LG:2560x1440"]
            ) != nil
        )
    }

    @Test("SpacePlacement: pin → Main → plan → main")
    func placementPrecedence() {
        let a = Display(
            id: DisplayID(1),
            name: "A",
            frame: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let b = Display(
            id: DisplayID(2),
            name: "B",
            frame: CGRect(x: 1, y: 0, width: 2, height: 2)
        )
        func resolve(
            _ space: SpaceID
        ) -> SpacePlacement.Resolution? {
            SpacePlacement.resolve(
                space: space,
                pins: [
                    SpaceID(2): "B:2x2",
                    SpaceID(4): "GONE:9x9",
                ],
                mainSpaces: [SpaceID(1)],
                displays: [a, b],
                mainID: DisplayID(1),
                assignment: [SpaceID(3): DisplayID(2)]
            )
        }
        #expect(resolve(SpaceID(2)) == .pinned(b))
        #expect(resolve(SpaceID(1)) == .main(a))
        #expect(resolve(SpaceID(3)) == .auto(b))
        // Off-plan spaces land on main.
        #expect(resolve(SpaceID(9)) == .auto(a))
        // A pin to a disconnected monitor keeps the intent
        // and falls back like an unpinned space would.
        #expect(
            resolve(SpaceID(4))
                == .pinnedAbsent(intent: "GONE:9x9", fallback: a)
        )
        // No displays: the only unresolvable state.
        #expect(
            SpacePlacement.resolve(
                space: SpaceID(1),
                pins: [:],
                mainSpaces: [],
                displays: [],
                mainID: nil,
                assignment: [:]
            ) == nil
        )
    }

    @Test("space_modes encodes as a JSON object")
    func spaceModesEncodesAsObject() throws {
        // Pins the CodingKeyRepresentable shape: [SpaceID:
        // LayoutMode] must serialize as {"1": "stack"}, not
        // as a flattened key/value array.
        let profile = makeProfile(
            name: "p",
            monitors: ["A:1x1"],
            modes: ["1": .stack]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(
            decoding: try encoder.encode(profile),
            as: UTF8.self
        )
        #expect(json.contains("\"space_modes\":{\"1\""))
    }

    @Test("Upsert replaces the same set, refuses new lengths")
    func upsert() {
        var profile = makeProfile(
            name: "p",
            monitors: ["A:1x1"]
        )
        let replaced = MonitorSet(
            monitors: ["A:1x1"],
            spaceMonitorMap: [SpaceID(1): "A:1x1"]
        )
        let sameSet = profile.upsert(replaced)
        #expect(sameSet)
        #expect(profile.monitorSets.count == 1)
        #expect(
            profile.monitorSets[0].spaceMonitorMap.count == 1
        )
        let newSet = profile.upsert(
            MonitorSet(monitors: ["B:2x2"])
        )
        #expect(newSet)
        #expect(profile.monitorSets.count == 2)
        let wrongLength = profile.upsert(
            MonitorSet(monitors: ["C:3x3", "D:4x4"])
        )
        #expect(!wrongLength)
    }

    /// Derived from `currentFormat`, never spelled: the subject is
    /// that a fresh profile carries THE current stamp and survives
    /// the round trip, which is true at every format. A literal
    /// reds on each deliberate bump and catches no regression
    /// (tests.md, #1021).
    @Test("Profile round-trips the current format by default")
    func profileFormatRoundTrip() throws {
        let current = Profile.currentFormat
        let profile = makeProfile(name: "p", monitors: ["A:1x1"])
        #expect(profile.format == current)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(profile)
        let json = String(decoding: data, as: UTF8.self)
        #expect(
            json.contains("\"format\":\(current)")
                || json.contains("\"format\" : \(current)")
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Profile.self, from: data)
        // Decoding an OLDER stamp, not the one just encoded:
        // `init(from:)` assigns `format = Self.currentFormat`
        // unconditionally, so re-decoding what we wrote asserts
        // nothing — it cannot fail (`guard-prover`, 2026-08-27).
        // What has content is that a file stamped below current
        // comes back UPGRADED, which is what lets a migrated file
        // be written back at the new format.
        let older = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(
                of: "\"format\":\(current)",
                with: "\"format\":0"
            )
            .replacingOccurrences(
                of: "\"format\" : \(current)",
                with: "\"format\" : 0"
            )
        #expect(older != String(decoding: data, as: UTF8.self))
        let upgraded = try decoder.decode(
            Profile.self,
            from: Data(older.utf8)
        )
        #expect(upgraded.format == current)
    }
}
