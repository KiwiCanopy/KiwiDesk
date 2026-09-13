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
@Suite("Track limit migration (#1354)")
struct TrackLimitMigrationTests {
    private func json(_ text: String) -> Data { Data(text.utf8) }

    /// A PROFILE-shaped root one below the floor the lift
    /// crossed — derived from the current format, so a later
    /// bump does not turn this fixture into a current file.
    private func profile(_ settings: String) -> Data {
        json(
            """
            {"format":\(Profile.currentFormat - 1),\
            "monitor_sets":{},"settings":\(settings)}
            """
        )
    }

    private func track(_ data: Data) throws -> [String: Any] {
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let settings = try #require(root["settings"] as? [String: Any])
        return try #require(settings["track"] as? [String: Any])
    }

    @Test("a stored limit is lifted by one, its siblings kept")
    func storedLimitIsLifted() throws {
        let data = profile(
            #"{"track":{"limit":2,"axis":"vertical","auto_tracks":false}}"#
        )
        let migrated = try #require(ConfigMigration.migrated(data))
        let track = try track(migrated)
        #expect(track["limit"] as? Int == 3)
        #expect(track["axis"] as? String == "vertical")
        #expect(track["auto_tracks"] as? Bool == false)
    }

    @Test("a stored 1 lands on the floor")
    func storedOneLandsOnTheFloor() throws {
        let data = profile(#"{"track":{"limit":1}}"#)
        let migrated = try #require(ConfigMigration.migrated(data))
        #expect(try track(migrated)["limit"] as? Int == TrackParams.minLimit)
    }

    @Test("every per-Space override is lifted too")
    func overridesAreLifted() throws {
        let data = profile(
            #"{"track":{"limit":3,"override":{"2":{"limit":4},"#
                + #""5":{"axis":"horizontal"}}}}"#
        )
        let migrated = try #require(ConfigMigration.migrated(data))
        let track = try track(migrated)
        let overrides = try #require(track["override"] as? [String: Any])
        #expect((overrides["2"] as? [String: Any])?["limit"] as? Int == 5)
        #expect((overrides["5"] as? [String: Any])?["limit"] == nil)
        #expect(
            (overrides["5"] as? [String: Any])?["axis"] as? String
                == "horizontal"
        )
    }

    @Test("a profile with no track group takes only the stamp")
    func noTrackGroupIsOnlyStamped() throws {
        let data = profile(#"{"gap":{"inner":8}}"#)
        let migrated = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: migrated) as? [String: Any]
        )
        #expect(root["format"] as? Int == Profile.currentFormat)
        let settings = try #require(root["settings"] as? [String: Any])
        #expect(settings["track"] == nil)
    }

    @Test("a current-format file is never lifted again")
    func currentFileIsLeftAlone() throws {
        let data = json(
            """
            {"format":\(Profile.currentFormat),"monitor_sets":{},\
            "settings":{"track":{"limit":3}}}
            """
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }

    @Test("the surgical edit keeps the file's own bytes around the lift")
    func surgicalEditKeepsTheBytes() throws {
        // A Double the walk's serializer would re-spell (the
        // reason the textual edit exists): it must survive.
        let data = profile(
            #"{"track":{"limit":2},"stack":{"master_ratio":0.4}}"#
        )
        let migrated = try #require(ConfigMigration.migrated(data))
        let text = try #require(String(data: migrated, encoding: .utf8))
        #expect(text.contains("0.4}"))
        #expect(text.contains(#""limit":3"#))
    }

    @Test("a bundle's inline profiles are lifted by path")
    func bundleProfilesAreLifted() throws {
        let data = json(
            """
            {"\(SetupBundle.shapeMarker)":true,\
            "format":\(SetupBundle.currentFormat - 1),\
            "profiles":[{"format":\(Profile.currentFormat - 1),\
            "monitor_sets":{},"settings":{"track":{"limit":2}}}]}
            """
        )
        let migrated = try #require(ConfigMigration.migrated(data))
        let root = try #require(
            JSONSerialization.jsonObject(with: migrated) as? [String: Any]
        )
        let profiles = try #require(root["profiles"] as? [[String: Any]])
        let settings = try #require(
            profiles.first?["settings"] as? [String: Any]
        )
        #expect((settings["track"] as? [String: Any])?["limit"] as? Int == 3)
    }
}
