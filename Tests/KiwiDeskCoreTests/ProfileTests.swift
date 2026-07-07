import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeManager() -> ProfileManager {
    ProfileManager(
        directory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-profiles-\(UUID().uuidString)"
            )
    )
}

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
                == .pinnedAbsent("GONE:9x9", fallback: a)
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
}

@Suite("ProfileManager", .serialized)
@MainActor
struct ProfileManagerTests {
    @Test("Save, list, and load round-trip")
    func roundTrip() throws {
        let manager = makeManager()
        let profile = makeProfile(
            name: "Developer Rig",
            monitors: ["LG 27:2560x1440"],
            pins: [SpaceID("code"): "LG 27:2560x1440"],
            mains: [SpaceID("music")],
            modes: ["code": .bsp, "music": .floating]
        )
        try manager.save(profile)
        #expect(manager.list() == ["Developer Rig"])
        let loaded = try manager.load(name: "Developer Rig")
        // The first profile of a count is auto-flagged default.
        #expect(loaded.isDefault)
        var expected = profile
        expected.isDefault = true
        #expect(loaded == expected)
        #expect(manager.currentName == "Developer Rig")
        #expect(!manager.isDirty)
    }

    @Test("Exact set match wins over the count default")
    func matchPriority() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(
                name: "docked",
                monitors: ["LG 27:2560x1440"]
            )
        )
        try manager.save(
            makeProfile(
                name: "a-default",
                monitors: ["Dell 24:1920x1080"],
                isDefault: true
            )
        )
        let match = manager.match(
            fingerprints: ["LG 27:2560x1440"]
        )
        guard case .exact(let profile) = match else {
            Issue.record("expected exact match, got \(match)")
            return
        }
        #expect(profile.name == "docked")
    }

    @Test("Unknown monitors fall back to the count default")
    func countDefaultFallback() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(
                name: "dual",
                monitors: ["A:1x1", "B:2x2"]
            )
        )
        let match = manager.match(
            fingerprints: ["C:3x3", "D:4x4"]
        )
        guard case .countDefault(let profile) = match else {
            Issue.record("expected default, got \(match)")
            return
        }
        #expect(profile.name == "dual")
        // No profile of that count at all -> none.
        #expect(
            manager.match(fingerprints: ["C:3x3"]) == .none
        )
    }

    @Test("First profile of a count becomes its default")
    func autoDefault() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(name: "first", monitors: ["A:1x1"])
        )
        try manager.save(
            makeProfile(name: "second", monitors: ["B:2x2"])
        )
        #expect(
            manager.defaultProfile(count: 1)?.name == "first"
        )
        #expect(try !manager.read(name: "second").isDefault)
    }

    @Test("Deleting the default hands the flag on")
    func deleteReassignsDefault() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(name: "alpha", monitors: ["A:1x1"])
        )
        try manager.save(
            makeProfile(name: "beta", monitors: ["B:2x2"])
        )
        try manager.delete(name: "alpha")
        #expect(manager.list() == ["beta"])
        #expect(
            manager.defaultProfile(count: 1)?.name == "beta"
        )
    }

    @Test("setDefault re-designates within the count")
    func setDefault() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(name: "alpha", monitors: ["A:1x1"])
        )
        try manager.save(
            makeProfile(name: "beta", monitors: ["B:2x2"])
        )
        try manager.setDefault(name: "beta")
        #expect(
            manager.defaultProfile(count: 1)?.name == "beta"
        )
        #expect(try !manager.read(name: "alpha").isDefault)
        #expect(manager.duplicateDefaultCounts().isEmpty)
    }

    @Test("freeName suffixes to the next free number")
    func freeName() throws {
        let manager = makeManager()
        #expect(manager.freeName(base: "Developer") == "Developer")
        try manager.save(
            makeProfile(name: "Developer", monitors: ["A:1x1"])
        )
        #expect(
            manager.freeName(base: "Developer") == "Developer_1"
        )
        try manager.save(
            makeProfile(
                name: "Developer_1",
                monitors: ["A:1x1"]
            )
        )
        #expect(
            manager.freeName(base: "Developer") == "Developer_2"
        )
    }

    @Test("Invalid profile files are skipped, not fatal")
    func invalidSkipped() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-profiles-\(UUID().uuidString)"
            )
        let manager = ProfileManager(directory: directory)
        try manager.save(
            makeProfile(name: "good", monitors: ["A:1x1"])
        )
        try "not json".write(
            to: directory.appendingPathComponent("bad.json"),
            atomically: true,
            encoding: .utf8
        )
        #expect(manager.list() == ["bad", "good"])
        #expect(manager.allProfiles().map(\.name) == ["good"])
    }
}
