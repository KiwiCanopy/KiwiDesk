import Foundation
import Testing

@testable import KiwiDeskCore

/// The `animations.scroll_speed` → `animations.scroll_duration`
/// crossing (#1020), across every file shape that stores one.
///
/// The failure it guards is SILENT, which is why the assertions
/// are about the value and not merely about decoding.
/// `AnimationSettings` decodes each knob with
/// `decodeIfPresent ?? 150` — the missing-keys contract a sparse
/// profile needs — so a file left carrying the retired spelling
/// decodes happily with the user's tuned value replaced by the
/// default, and is then saved back without it. Nothing reports
/// anything. A test that only asserted "still decodes" would
/// pass on exactly the bug.
@Suite("Scroll duration migration")
struct ScrollDurationMigrationTests {
    private func json(_ raw: String) -> Data { Data(raw.utf8) }

    private func animations(
        _ data: Data
    ) throws -> [String: Any] {
        let root =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        let settings = root?["settings"] as? [String: Any]
        return try #require(
            settings?["animations"] as? [String: Any]
        )
    }

    /// A profile written before the rename keeps its VALUE, not
    /// just its readability.
    @Test("A retired profile key is renamed, value intact")
    func profileKeyMigrates() throws {
        let data = json(
            """
            {"monitor_sets":[],"settings":\
            {"animations":{"scroll_speed":420}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let knobs = try animations(out)
        #expect(knobs["scroll_duration"] as? Int == 420)
        #expect(knobs["scroll_speed"] == nil)
        // ...and the whole point: decoding it back gives the
        // tuned value rather than the 150 ms default.
        let settings = try JSONDecoder().decode(
            TilingSettings.self,
            from: try #require(
                JSONSerialization.data(
                    withJSONObject: try #require(
                        (try JSONSerialization.jsonObject(
                            with: out
                        ) as? [String: Any])?["settings"]
                    )
                )
            )
        )
        #expect(settings.animations.scrollDurationMS == 420)
    }

    /// The bump is what RUNS the crossing, so a profile stamped
    /// with the PREVIOUS format must still be reached. Pinned as
    /// "one below current" rather than as the literal 1, so it
    /// keeps meaning that after the next bump.
    @Test("A previous-format profile is still migrated")
    func previousFormatIsReached() throws {
        let data = json(
            """
            {"format":\(Profile.currentFormat - 1),\
            "monitor_sets":[],"settings":\
            {"animations":{"scroll_speed":420}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        #expect(
            try animations(out)["scroll_duration"] as? Int == 420
        )
    }

    /// A bundle carries `[Profile]` inline and is never rewritten
    /// on disk, so a refusal there is permanent — the #945 class.
    @Test("The key is renamed inside a bundle's profiles too")
    func bundleProfilesMigrate() throws {
        let data = json(
            """
            {"format":\(SetupBundle.currentFormat - 1),\
            "writtenBy":"1.0.1","profiles":[{"settings":\
            {"animations":{"scroll_speed":420}}}],\
            "palettes":[]}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root =
            try JSONSerialization.jsonObject(with: out)
            as? [String: Any]
        let profiles = try #require(
            root?["profiles"] as? [[String: Any]]
        )
        let settings = profiles[0]["settings"] as? [String: Any]
        let knobs = try #require(
            settings?["animations"] as? [String: Any]
        )
        #expect(knobs["scroll_duration"] as? Int == 420)
        #expect(knobs["scroll_speed"] == nil)
    }

    /// The rename is keyed on a KEY, so a string VALUE that reads
    /// the same — a Space someone named `scroll_speed` — is not
    /// touched. The surgical edit requires the trailing colon
    /// precisely so this holds.
    @Test("A value reading `scroll_speed` is left alone")
    func valueSpellingIsNotAKey() throws {
        let data = json(
            """
            {"monitor_sets":[],"spaces":["scroll_speed"],\
            "settings":{"animations":{"scroll_duration":420}}}
            """
        )
        // Nothing to rename, so the file is not rewritten at all
        // beyond a format stamp; the space name survives either
        // way, which is what is asserted.
        let out = ConfigMigration.migrated(data) ?? data
        let root =
            try JSONSerialization.jsonObject(with: out)
            as? [String: Any]
        #expect(root?["spaces"] as? [String] == ["scroll_speed"])
        #expect(
            try animations(out)["scroll_duration"] as? Int == 420
        )
    }

    /// Both spellings present means the file was written by a
    /// build that already had the rename, so the retired sibling
    /// is stale and the new one wins.
    @Test("A node carrying both spellings keeps the new one")
    func bothSpellingsKeepsTheNewValue() throws {
        let data = json(
            """
            {"monitor_sets":[],"settings":{"animations":\
            {"scroll_speed":50,"scroll_duration":420}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let knobs = try animations(out)
        #expect(knobs["scroll_duration"] as? Int == 420)
        #expect(knobs["scroll_speed"] == nil)
    }

    /// The surgical edit exists so a one-key migration does not
    /// re-encode every float in the user's file (the measured
    /// `0.4` → `0.40000000000000002`, ConfigMigration's own note).
    @Test("Floats elsewhere in the file are not re-encoded")
    func floatsSurviveTheRename() throws {
        let data = json(
            """
            {"monitor_sets":[],"settings":{"gap":0.4,\
            "animations":{"scroll_speed":420}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let text = String(decoding: out, as: UTF8.self)
        #expect(text.contains("0.4"))
        #expect(!text.contains("0.40000000000000002"))
    }
}
