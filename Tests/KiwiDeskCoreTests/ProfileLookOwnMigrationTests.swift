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

    /// The format before the key existed — spelled, so a change to
    /// the step's own constant cannot move the fixture with it.
    private let beforeLook = 12
    private let bundleBeforeLook = 17

    /// `data` restamped at the format before the key existed.
    private func older(_ data: Data) -> Data {
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(
                of: "\"format\" : \(Profile.currentFormat)",
                with: "\"format\" : \(beforeLook)"
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

    /// A layout the re-encoder would change — four-space indent,
    /// unsorted keys, `0.40` — so an exact match proves the stamp
    /// is inserted and nothing else is touched.
    @Test("the stamp is inserted in place")
    func stampIsSurgical() throws {
        let text = """
            {
                "settings": { "ratio": 0.40 },
                "monitor_sets": [],
                "format": \(beforeLook)
            }
            """
        let out = try #require(ConfigMigration.migrated(Data(text.utf8)))
        let result = String(decoding: out, as: UTF8.self)
        let expected = text.replacingOccurrences(
            of: "{\n",
            with: "{\n  \"look\" : \"own\",\n"
        )
        #expect(stampless(result) == stampless(expected))
    }

    /// Without the stamp and the Space Bar grouping a pre-#1725
    /// profile gains, both the envelope's rather than this step's.
    private func stampless(_ text: String) -> String {
        text.replacingOccurrences(
            of: #""format"\s*:\s*\d+"#,
            with: "",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #""space_bar":\{"group_adjacent_windows":true\},?"#,
            with: "",
            options: .regularExpression
        )
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
        root["format"] = bundleBeforeLook
        let old = try JSONSerialization.data(withJSONObject: root)
        let migrated = try #require(ConfigMigration.migrated(old))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(SetupBundle.self, from: migrated)
        #expect(back.profiles.map(\.look) == [.own])
    }
}
