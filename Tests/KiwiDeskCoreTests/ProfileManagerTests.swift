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

    @Test("freeName collides case-insensitively (APFS)")
    func freeNameCaseInsensitive() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(name: "my setup", monitors: ["A:1x1"])
        )
        // "My Setup.json" would overwrite "my setup.json" on
        // a case-insensitive filesystem — the availability
        // rule must treat them as the same name.
        #expect(
            manager.freeName(base: "My Setup") == "My Setup_1"
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
        // The same file `allProfiles()` skips is the one the GUI
        // greys out and offers a Reveal and a Delete for (#246).
        #expect(manager.brokenProfiles().map(\.name) == ["bad"])
        // "not json" is not JSON, so the row may promise that
        // opening the file shows the damage (#678 Phase 4 pass 9).
        #expect(
            manager.brokenProfiles().map(\.cause) == [.malformedJSON]
        )
    }

    @Test("A broken profile's cause splits syntax from shape")
    func brokenCauseSplitsSyntaxFromShape() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-profiles-\(UUID().uuidString)"
            )
        let manager = ProfileManager(directory: directory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        // Valid JSON the decoder reaches into and rejects: an
        // object with none of the keys `Profile` requires. The
        // user cannot see anything wrong by opening it, which is
        // the whole reason the two causes read differently.
        try "{\"nope\": 1}".write(
            to: directory.appendingPathComponent("shape.json"),
            atomically: true,
            encoding: .utf8
        )
        // Not JSON at all — a lost brace, visible on sight.
        try "{".write(
            to: directory.appendingPathComponent("syntax.json"),
            atomically: true,
            encoding: .utf8
        )
        let causes = Dictionary(
            uniqueKeysWithValues: manager.brokenProfiles().map {
                ($0.name, $0.cause)
            }
        )
        #expect(causes["shape"] == .unexpectedShape)
        #expect(causes["syntax"] == .malformedJSON)
    }

    @Test("Delete repairs a count left without a default")
    func deleteRepairsDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-profiles-\(UUID().uuidString)"
            )
        let manager = ProfileManager(directory: directory)
        try manager.save(
            makeProfile(name: "alpha", monitors: ["A:1x1"])
        )
        try "not json".write(
            to: directory.appendingPathComponent(
                "broken.json"
            ),
            atomically: true,
            encoding: .utf8
        )
        // Simulate the hand-edited state where no profile of
        // the count carries the default flag.
        var plain = try manager.read(name: "alpha")
        plain.isDefault = false
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(plain).write(
            to: directory.appendingPathComponent("alpha.json")
        )
        // The deleted file is unreadable, so its count is
        // unknown — every orphaned count gets repaired.
        try manager.delete(name: "broken")
        #expect(
            manager.defaultProfile(count: 1)?.name == "alpha"
        )
    }

    @Test("Deleting one duplicate default flags no third")
    func deleteDuplicateDefault() throws {
        let manager = makeManager()
        try manager.save(
            makeProfile(name: "alpha", monitors: ["A:1x1"])
        )
        try manager.save(
            makeProfile(
                name: "beta",
                monitors: ["B:2x2"],
                isDefault: true
            )
        )
        // Hand-edited duplicate: alpha (auto) and beta both
        // hold the flag for count 1.
        #expect(
            manager.duplicateDefaultCounts() == [1]
        )
        try manager.delete(name: "beta")
        // alpha still holds the flag; the count has exactly
        // one default and no heir was invented.
        #expect(
            manager.defaultProfile(count: 1)?.name == "alpha"
        )
        #expect(manager.duplicateDefaultCounts().isEmpty)
    }
}
