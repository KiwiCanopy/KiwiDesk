import Foundation
import Testing

@testable import KiwiDeskCore

/// The migration's own contract — what it leaves alone, that it
/// runs once, and that a v0.9.7 profile decodes after it — told
/// through the oldest profile shape this build still reads. The
/// retired `app_bar.content` step's own clauses are
/// `AppBarContentMigrationTests`'.
@Suite("Config migration")
struct ConfigMigrationTests {
    private func json(_ raw: String) -> Data { Data(raw.utf8) }

    /// Nil, not the same bytes: the callers write back exactly
    /// when this returns non-nil, so a config with nothing to do
    /// must never have its file rewritten. Since the #945 stamp
    /// fix, "nothing to do" requires the format to be current —
    /// an unversioned file is stamped even with current values
    /// (`unversionedFileWithNothingToRewriteIsStamped`).
    @Test("A current config is left alone")
    func currentConfigIsUntouched() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),\
            "settings":{"app_bar":{"edge":"top"}}}
            """
        )
        #expect(
            ConfigMigration.migrated(data)
                == nil
        )
    }

    /// Running twice changes nothing the second time — the
    /// property the best-effort write-back depends on, since a
    /// read-only config directory makes every launch retry.
    @Test("The migration is idempotent")
    func migrationIsIdempotent() throws {
        let data = json(
            """
            {"settings":{"app_bar":{"content":"name"}}}
            """
        )
        let once = try #require(
            ConfigMigration.migrated(data)
        )
        #expect(
            ConfigMigration.migrated(once)
                == nil
        )
    }

    /// The end-to-end claim, in the shape the user meets it: a
    /// v0.9.7 profile decodes again.
    ///
    /// Built by ENCODING a real profile and then downgrading the
    /// one value, rather than hand-writing the JSON: the fixture
    /// then carries whatever shape `Profile` currently requires,
    /// so this cannot rot into testing a file no build ever
    /// wrote.
    @Test("A v0.9.7 profile decodes after migrating")
    func retiredProfileDecodes() throws {
        let settings = TilingSettings()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let current = try encoder.encode(
            Profile(
                format: 0,
                name: "Starter",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [SpaceID(1): .monocle],
                settings: settings
            )
        )
        // ...as v0.9.7 would have written it: the App Bar's
        // retired `content` spelling, and the track limit one
        // below today's, which is what that build stored for the
        // picture today's default draws (#1354's lift).
        var root = try #require(
            JSONSerialization.jsonObject(with: current)
                as? [String: Any]
        )
        var tiling = try #require(root["settings"] as? [String: Any])
        var bar = try #require(tiling["app_bar"] as? [String: Any])
        bar["content"] = "icon_and_name"
        tiling["app_bar"] = bar
        root["settings"] = tiling
        let old = Data(
            String(
                decoding: try JSONSerialization.data(
                    withJSONObject: root
                ),
                as: UTF8.self
            )
            // Compact JSON here (no pretty-printing), so the key
            // and value abut.
            .replacingOccurrences(
                of: "\"limit\":\(TrackParams().limit)",
                with: "\"limit\":\(TrackParams().limit - 1)"
            ).utf8
        )
        #expect(
            String(decoding: old, as: UTF8.self)
                .contains("icon_and_name")
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let migrated = try #require(
            ConfigMigration.migrated(old)
        )
        let profile = try decoder.decode(
            Profile.self,
            from: migrated
        )
        // The whole VALUE, not two fields: the function rewrites
        // the entire file through a `JSONSerialization` round
        // trip, so anything it quietly changed elsewhere — a
        // number's representation, an escape, a dropped key —
        // belongs in the net. `Profile` is `Equatable`, so the
        // net costs one line.
        var original = try decoder.decode(
            Profile.self,
            from: current
        )
        // A v0.9.7 profile predates the shared look, so it arrives
        // wearing its own (#1752).
        original.look = .own
        #expect(profile == original)
        #expect(
            !String(decoding: migrated, as: UTF8.self)
                .contains("\"content\"")
        )
    }

    /// A config already carrying the CURRENT format skips
    /// migration immediately without scanning payload.
    ///
    /// The number is derived, not spelled: the claim is about a
    /// file at whatever this build writes, which stays true across
    /// every bump, while a literal reds on each one and guards
    /// nothing (tests.md, #1021). This fixture has no
    /// `monitor_sets`, so `targetFormat` routes it as a
    /// `GuiConfig` — the shape whose current format it must carry.
    ///
    /// **`needsMigration` is asserted directly, and that is the
    /// whole point of the test.** Asserting only
    /// `migrated(…) == nil` cannot tell "short-circuited at the
    /// format check" — the perf claim in this test's name — from
    /// "ran every step and found nothing to change": the two have
    /// the same outcome, so the assertion stayed green with
    /// `needsMigration` mutated to always-true, rescued by the
    /// never-rewrite-untouched contract on a second route
    /// (`guard-prover`, 2026-08-27). Three sibling tests below
    /// assert that same outcome and are the second net; this one
    /// names the gate.
    @Test("A current-format config skips migration")
    func currentFormatSkipsMigration() {
        let data = json(
            """
            {"format":\(GuiConfig.currentFormat),"settings":\
            {"app_bar":{"edge":"top"}}}
            """
        )
        #expect(
            !ConfigMigration.needsMigration(data),
            Comment(
                rawValue:
                    "a config already at the current format is "
                    + "being scanned — the short-circuit is gone, "
                    + "so every read parses and walks the payload"
            )
        )
        #expect(ConfigMigration.migrated(data) == nil)
    }

    /// A profile carrying a newer format than supported is refused.
    @Test("A profile with newer format is refused")
    func newerProfileFormatIsRefused() throws {
        let future = Profile.currentFormat + 1
        let data = json(
            """
            {"format":\(future),"name":"Future","monitor_sets":\
            [{"monitors":["A:100x100"]}],"space_modes":{"1":"bsp"},\
            "settings":{}}
            """
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: data)
        }
    }

    /// A GuiConfig carrying a newer format than supported is refused.
    @Test("A GuiConfig with newer format is refused")
    func newerGuiConfigFormatIsRefused() {
        let future = GuiConfig.currentFormat + 1
        let data = json(
            """
            {"format":\(future),"spaces":["1"]}
            """
        )
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(GuiConfig.self, from: data)
        }
    }
}
