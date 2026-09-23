import Foundation
import Testing

@testable import KiwiDeskCore

private func makeProfile(monitors: [String]) -> Profile {
    Profile(
        name: "p",
        monitorSets: [MonitorSet(monitors: monitors)],
        spaceModes: ["1": .bsp],
        settings: TilingSettings(),
        // Whole seconds: profile files store ISO-8601 dates.
        savedAt: Date(timeIntervalSince1970: 1_780_000_000)
    )
}

/// The dormant profile's file shape (#1530): no monitor set
/// beside a `monitor_count`, amending #36's "zero sets is invalid".
/// Split from `ProfileModelTests` at the §2.1 target.
@Suite("Dormant profile file shape (#1530)")
struct DormantProfileModelTests {
    /// #1530 amends #36: zero sets is valid when the count rides
    /// along — a dormant profile.
    @Test("A dormant profile decodes from its monitor_count")
    func dormantDecodes() throws {
        let json = """
            {"name": "resting", "monitor_sets": [],
             "monitor_count": 2,
             "space_modes": {}, "settings": {},
             "saved_at": "2026-06-01T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(
            Profile.self,
            from: Data(json.utf8)
        )
        #expect(profile.isDormant)
        #expect(profile.monitorCount == 2)
    }

    @Test("A zero monitor_count does not make a dormant profile")
    func zeroCountRefused() {
        let json = """
            {"name": "broken", "monitor_sets": [],
             "monitor_count": 0,
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

    @Test("Release keeps the count; upsert wakes it at that count")
    func releaseAndWake() throws {
        var profile = makeProfile(monitors: ["A:1x1", "B:2x2"])
        let missing = profile.release(["C:3x3", "D:4x4"])
        #expect(!missing)
        let released = profile.release(["B:2x2", "A:1x1"])
        #expect(released)
        #expect(profile.isDormant)
        #expect(profile.monitorCount == 2)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(
            Profile.self,
            from: encoder.encode(profile)
        )
        #expect(back == profile)
        let wrongCount = profile.upsert(
            MonitorSet(monitors: ["C:3x3"])
        )
        #expect(!wrongCount)
        let woke = profile.upsert(
            MonitorSet(monitors: ["C:3x3", "D:4x4"])
        )
        #expect(woke)
        #expect(!profile.isDormant)
        // A profile holding a set writes no `monitor_count`: the
        // set states the count.
        let json = try #require(
            String(data: encoder.encode(profile), encoding: .utf8)
        )
        #expect(!json.contains("monitor_count"))
    }
}
