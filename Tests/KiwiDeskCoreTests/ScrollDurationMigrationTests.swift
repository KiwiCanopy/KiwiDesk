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

    /// The bump is what RUNS the crossing.
    ///
    /// **The `1` is deliberate and must not be derived.** It is
    /// the format v1.0.1 SHIPPED — a past-tense fact, which
    /// rule-authoring.md exempts from the pin-the-shape rule —
    /// and it is the whole subject: written as
    /// `currentFormat - 1` this test followed the bump down and
    /// stayed green when the bump was reverted, guarding nothing
    /// on exactly the revert the change exists to prevent
    /// (`code-reviewer`, 2026-08-27). `needsMigration` is
    /// asserted directly, because that is the gate that decides.
    @Test("A profile at the format 1.0.1 shipped is migrated")
    func shippedFormatIsReached() throws {
        let data = json(
            """
            {"format":1,"monitor_sets":[],"settings":\
            {"animations":{"scroll_speed":420}}}
            """
        )
        #expect(
            ConfigMigration.needsMigration(data),
            Comment(
                rawValue:
                    "a profile at format 1 no longer needs "
                    + "migration — Profile.currentFormat must "
                    + "exceed the format 1.0.1 wrote, or this "
                    + "crossing never runs on the files it "
                    + "exists to rescue"
            )
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
    /// touched, while a real key beside it still is.
    ///
    /// **Two claims, and they are guarded by different things**
    /// (`code-reviewer`, 2026-08-27). That the VALUE survives is
    /// the envelope's doing: drop the colon from the regex and
    /// the edit also rewrites the space name, the re-parse
    /// disagrees with the walk's tree, and the tree fallback is
    /// serialized instead — correct output either way. What the
    /// colon actually buys is that the SURGICAL path stays
    /// usable, which is visible only in the bytes: the float
    /// below survives un-re-encoded exactly when the edit was
    /// used. Asserting only the value would pass with the colon
    /// deleted, which is what the first draft of this test did.
    @Test("A value reading `scroll_speed` is left alone")
    func valueSpellingIsNotAKey() throws {
        let data = json(
            """
            {"monitor_sets":[],"spaces":["scroll_speed"],\
            "settings":{"gap":0.4,"animations":\
            {"scroll_speed":420}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let root =
            try JSONSerialization.jsonObject(with: out)
            as? [String: Any]
        #expect(root?["spaces"] as? [String] == ["scroll_speed"])
        #expect(
            try animations(out)["scroll_duration"] as? Int == 420
        )
        // The surgical path was taken, not the tree fallback.
        let text = String(decoding: out, as: UTF8.self)
        #expect(text.contains("0.4"))
        #expect(!text.contains("0.40000000000000002"))
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

    /// The same node in the order `.sortedKeys` actually
    /// produces — which is the order on disk, since
    /// `ProfileManager` writes with it.
    ///
    /// This is the arm that shipped broken: a textual rename
    /// cannot see a sibling, so it produced `scroll_duration`
    /// TWICE in one object, and the envelope's value-compare
    /// could not see it because `JSONSerialization` keeps the
    /// first occurrence and `.sortedKeys` puts the correct value
    /// there. Foundation read 420 out of those bytes and
    /// `jq`/Python read the stale 50 — one file, two answers.
    /// The other ordering (above) takes the tree fallback and so
    /// never exercised this (`code-reviewer`, 2026-08-27).
    @Test("Both spellings, sorted order, yield no duplicate key")
    func bothSpellingsSortedOrderIsNotDuplicated() throws {
        let data = json(
            """
            {"monitor_sets":[],"settings":{"animations":\
            {"scroll_duration":420,"scroll_speed":50}}}
            """
        )
        let out = try #require(ConfigMigration.migrated(data))
        let text = String(decoding: out, as: UTF8.self)
        // The defect is visible in the BYTES, which is the only
        // place it is visible: every value-level assertion below
        // passed while the file was corrupt.
        #expect(
            text.components(
                separatedBy: "\"scroll_duration\""
            ).count - 1 == 1,
            Comment(
                rawValue:
                    "`scroll_duration` appears more than once — "
                    + "the surgical rename duplicated a key: "
                    + text
            )
        )
        #expect(!text.contains("\"scroll_speed\""))
        let knobs = try animations(out)
        #expect(knobs["scroll_duration"] as? Int == 420)
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
