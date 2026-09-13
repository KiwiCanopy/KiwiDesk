import Foundation
import Testing

@testable import KiwiDeskCore

/// The track limit's crossing (#1354): a stored `limit` counted
/// NORMAL tracks with the overflow track beside them, and now
/// counts the tracks on screen, so every stored value is lifted
/// by one and nobody's layout changes on update — a stored 2
/// drew three tracks and becomes 3; a stored 1 lands on the new
/// floor. The failure this prevents is silent: a file left as it
/// was decodes fine and shows one track fewer.
///
/// Every fixture is what the ENCODER writes, re-stamped below
/// the floor — never a hand-written shape. The first draft
/// spelled `settings.track` where the file says
/// `settings.layout.track`, went green on its own fixtures, and
/// stamped the owner's real profiles to the new format with
/// nothing lifted (device, 2026-09-13): a hand-written fixture
/// proves the step against the fixture, not against the file.
@Suite("Track limit migration (#1354)")
struct TrackLimitMigrationTests {
    /// A profile file as this build writes it, with `limit`
    /// (and optionally one override) set, stamped `format`.
    private func profile(
        limit: Int,
        override: (SpaceID, Int)? = nil,
        format: Int = ConfigMigration.trackLiftProfileFormat - 1
    ) throws -> Data {
        var settings = TilingSettings()
        settings.track.limit = limit
        settings.stack.masterRatio = 0.4
        if let (space, value) = override {
            var over = TrackOverride()
            over.limit = value
            settings.track.override[space] = over
        }
        let profile = Profile(
            format: format,
            name: "P",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: settings
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(profile)
    }

    private func decoded(_ data: Data) throws -> Profile {
        try JSONDecoder().decode(Profile.self, from: data)
    }

    private func track(_ data: Data) throws -> [String: Any] {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        let layout = try #require(settings["layout"] as? [String: Any])
        return try #require(layout["track"] as? [String: Any])
    }

    @Test("a stored limit is lifted by one, its siblings kept")
    func storedLimitIsLifted() throws {
        let data = try profile(limit: 2)
        let migrated = try #require(ConfigMigration.migrated(data))
        let after = try decoded(migrated)
        #expect(after.settings.track.limit == 3)
        #expect(after.settings.track.axis == TrackParams().axis)
        #expect(after.format == Profile.currentFormat)
    }

    @Test("a stored 1 lands on the floor")
    func storedOneLandsOnTheFloor() throws {
        let data = try profile(limit: 1)
        let migrated = try #require(ConfigMigration.migrated(data))
        #expect(
            try decoded(migrated).settings.track.limit
                == TrackParams.minLimit
        )
    }

    @Test("every per-Space override is lifted too")
    func overridesAreLifted() throws {
        let data = try profile(limit: 3, override: (SpaceID(2), 4))
        let migrated = try #require(ConfigMigration.migrated(data))
        let after = try decoded(migrated)
        #expect(after.settings.track.limit == 4)
        #expect(after.settings.track.override[SpaceID(2)]?.limit == 5)
    }

    /// The step ENDS on its own: a lifted 3 is the same bytes as
    /// a typed 3, so the step reads the stamp rather than the
    /// value, and a file at the format it introduced — the next
    /// bump's population — is never lifted twice. Called
    /// directly: `migrated`'s own gate would rescue a current
    /// file and prove nothing about the step.
    @Test("the step stands down at the format it introduced")
    func stepIsIdempotent() throws {
        let profileAtFloor = try profile(
            limit: 3,
            format: ConfigMigration.trackLiftProfileFormat
        )
        #expect(
            ConfigMigration.migratingTrackLimitCount(profileAtFloor)
                == nil
        )
        let bundleAtFloor = try bundle(
            limit: 3,
            format: ConfigMigration.trackLiftBundleFormat
        )
        #expect(
            ConfigMigration.migratingTrackLimitCount(bundleAtFloor)
                == nil
        )
        // And one below either floor IS lifted, so the gate is
        // read from the right side.
        let profileBelow = try profile(limit: 3)
        #expect(
            ConfigMigration.migratingTrackLimitCount(profileBelow)
                != nil
        )
        let bundleBelow = try bundle(
            limit: 3,
            format: ConfigMigration.trackLiftBundleFormat - 1
        )
        #expect(
            ConfigMigration.migratingTrackLimitCount(bundleBelow)
                != nil
        )
    }

    @Test("the surgical edit keeps the file's own bytes around the lift")
    func surgicalEditKeepsTheBytes() throws {
        // A Double the walk's serializer would re-spell (the
        // reason the textual edit exists): it must survive, and
        // the lifted key keeps the encoder's spacing.
        let data = try profile(limit: 2)
        let migrated = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: migrated, encoding: .utf8))
        #expect(text.contains("\"master_ratio\" : 0.4"))
        #expect(text.contains("\"limit\" : 3"))
        #expect(try track(migrated)["limit"] as? Int == 3)
    }

    /// A bundle as `exportSetup` writes it, carrying one profile
    /// inline, re-stamped.
    private func bundle(limit: Int, format: Int) throws -> Data {
        let inner = try decoded(
            try profile(limit: limit, format: Profile.currentFormat)
        )
        let bundle = SetupBundle(
            format: format,
            writtenBy: "test",
            config: nil,
            profiles: [inner],
            palettes: []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    @Test("a bundle's inline profiles are lifted by path")
    func bundleProfilesAreLifted() throws {
        let data = try bundle(
            limit: 2,
            format: ConfigMigration.trackLiftBundleFormat - 1
        )
        let migrated = try #require(ConfigMigration.migrated(data))
        let after = try JSONDecoder().decode(
            SetupBundle.self,
            from: migrated
        )
        #expect(after.profiles.first?.settings.track.limit == 3)
    }
}
