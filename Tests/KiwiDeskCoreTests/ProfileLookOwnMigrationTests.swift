import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile written before #1752 is stamped `look: own` — an
/// absent `look` now means the shared look — in a profile file and
/// a bundle's inline profiles, while a current profile's absence
/// stays absence. Fixtures come from the encoder, restamped below
/// the format that introduced the key.
@Suite("Profile look migration (#1752)")
struct ProfileLookOwnMigrationTests {
    private func encoded(_ profile: Profile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(profile)
    }

    private func profile(look: LookReference? = nil) -> Profile {
        Profile(
            name: "Work",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            look: look
        )
    }

    /// `data` restamped at the format before the key existed.
    private func older(_ data: Data) -> Data {
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(
                of: "\"format\" : \(Profile.currentFormat)",
                with: "\"format\" : \(ConfigMigration.profileLookFormat - 1)"
            )
        return Data(text.utf8)
    }

    private func decoded(_ data: Data) throws -> Profile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    @Test("a profile from before wears its own look")
    func olderProfileIsOwn() throws {
        let old = older(try encoded(profile()))
        let migrated = try #require(ConfigMigration.migrated(old))
        #expect(try decoded(migrated).look == .own)
    }

    @Test("the stamp is inserted in place")
    func stampIsSurgical() throws {
        let old = older(try encoded(profile()))
        let migrated = try #require(ConfigMigration.migrated(old))
        let before = String(decoding: old, as: UTF8.self)
            .split(separator: "\n")
        let after = String(decoding: migrated, as: UTF8.self)
            .split(separator: "\n")
        // One line more: the stamp; the format line changes.
        #expect(after.count == before.count + 1)
        #expect(after.contains(#"  "look" : "own","#))
    }

    @Test("a current profile's absent look stays shared")
    func currentProfileIsUntouched() throws {
        let current = try encoded(profile())
        #expect(ConfigMigration.migrated(current) == nil)
        #expect(try decoded(current).look == nil)
    }

    @Test("a bundle's inline profiles are stamped too")
    func bundleProfilesCross() throws {
        let bundle = SetupBundle(
            writtenBy: "test",
            config: nil,
            profiles: [profile()],
            palettes: [],
            looks: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var root = try #require(
            try JSONSerialization.jsonObject(
                with: encoder.encode(bundle)
            ) as? [String: Any]
        )
        root["format"] = ConfigMigration.profileLookBundleFormat - 1
        let old = try JSONSerialization.data(withJSONObject: root)
        let migrated = try #require(ConfigMigration.migrated(old))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(SetupBundle.self, from: migrated)
        #expect(back.profiles.map(\.look) == [.own])
    }
}
