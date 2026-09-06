import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The track shortcut rows are whole localized sentences, one
/// key per row (#1110). The obligation behind them — an
/// interpolated value must not have to agree with the sentence
/// it lands in — is `.claude/rules/localization.md`'s to argue.
///
/// This suite is the net for a whole revert, not a second one:
/// `extract-keys --check` regenerates `en.json` FROM the call
/// sites, so a revert that moves them and re-prunes is
/// self-consistent and lints clean (`guard-prover`, 2026-09-06).
///
/// `.serialized`, and each body pins its own locale: the
/// consumer clause moves the process-wide `LocalizationManager`
/// (tests.md, #740). It restores `"en"` rather than `nil`,
/// which means the HOST's language — `DesktopAwayRowTests`
/// carries that argument.
@Suite("Track row sentences (#1110)", .serialized)
@MainActor
struct TrackRowSentenceTests {
    /// The four row keys, by family and step.
    private static let rowKeys: [(family: String, step: String, key: String)] =
        [
            ("move", "prev", "keybinding.move_window_to_prev_track"),
            ("move", "next", "keybinding.move_window_to_next_track"),
            ("swap", "prev", "keybinding.swap_with_prev_track"),
            ("swap", "next", "keybinding.swap_with_next_track"),
        ]

    /// The keys the frame shape needed — the two frames and the
    /// shared adjective they interpolated. Kept as a NEGATIVE
    /// clause: it cannot tax a future author, and their return
    /// is exactly the regression.
    private static let retiredKeys = [
        "keybinding.seq.prev", "keybinding.seq.next",
        "keybinding.move_window_to_track",
        "keybinding.swap_with_track",
    ]

    private static let localesDirectory = SourceScan.repoRoot(
        from: #filePath
    )
    .appendingPathComponent("Sources")
    .appendingPathComponent("KiwiDeskCore")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Locales")

    /// Every shipped catalog, decoded. Nothing is skipped: a file
    /// in that directory that is not a flat catalog is a defect
    /// its own suite (`SettingKeyLocaleTests`) names, and reading
    /// past it here would let a stray worksheet stand in for a
    /// missing translation.
    private static func catalogs() throws -> [String: [String: String]] {
        let files = try FileManager.default.contentsOfDirectory(
            at: localesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        var out: [String: [String: String]] = [:]
        for file in files {
            let data = try Data(contentsOf: file)
            let decoded = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            out[file.deletingPathExtension().lastPathComponent] =
                decoded
        }
        // Floored here rather than per clause: a scanning clause
        // over an empty fixture passes for having found no
        // violations (rule-authoring.md), and only two of the
        // five carry a floor of their own.
        #expect(out.count > 1)
        #expect(out["en"] != nil)
        return out
    }

    /// Every locale answers all four rows. A frame plus one
    /// shared fragment needed three values per catalog; four
    /// sentences need four, and a merge that skipped one would
    /// otherwise fall back to English in a Settings list where
    /// every neighbouring row is translated.
    @Test("every locale carries all four track rows")
    func everyLocaleCarriesTheFourRows() throws {
        let catalogs = try Self.catalogs()
        #expect(catalogs["en"] != nil)
        #expect(catalogs.count > 1)
        for (locale, catalog) in catalogs {
            for row in Self.rowKeys {
                #expect(
                    catalog[row.key]?.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty == false,
                    "\(locale): \(row.key) missing"
                )
            }
        }
    }

    /// Each row renders as-is. Scoped to these four keys, so it
    /// catches a specifier arriving in a shipped value — not a
    /// frame resurrected under its old name, which is the
    /// retired-key clause's (`guard-prover`, 2026-09-06).
    @Test("no track row value is a frame")
    func noTrackRowValueIsAFrame() throws {
        for (locale, catalog) in try Self.catalogs() {
            for row in Self.rowKeys {
                guard let value = catalog[row.key] else { continue }
                #expect(
                    !value.contains("%"),
                    "\(locale): \(row.key) interpolates (\(value))"
                )
            }
        }
    }

    /// The frame shape is gone from every catalog — both frames
    /// and the adjective no translator could have made right.
    /// This is the clause that answers a real revert: the call
    /// site coming back re-mints those keys, and nothing else
    /// here watches a key by the name it used to have.
    @Test("the retired frame keys are gone everywhere")
    func theRetiredFrameKeysAreGone() throws {
        for (locale, catalog) in try Self.catalogs() {
            for key in Self.retiredKeys {
                #expect(
                    catalog[key] == nil,
                    "\(locale): \(key) is back"
                )
            }
        }
    }

    /// Four distinct sentences per locale — the two steps differ,
    /// and so do the two verbs. One value serving two rows is the
    /// defect in its original form.
    @Test("the four rows are four different sentences")
    func theFourRowsAreDistinct() throws {
        for (locale, catalog) in try Self.catalogs() {
            let values = Self.rowKeys.compactMap { catalog[$0.key] }
            #expect(values.count == Self.rowKeys.count)
            #expect(
                Set(values).count == values.count,
                "\(locale): track rows share a value \(values)"
            )
        }
    }

    /// The CONSUMER clause: the rows the catalog builds carry
    /// the keys above, matched by the Lua step each row carries
    /// rather than by array order.
    ///
    /// Pinned to `de`, never `"en"`: `effectiveLocale`
    /// short-circuits an explicit `"en"` to `nil`, so every
    /// `L()` returns its own call-site literal, and comparing
    /// that against `en.json` — derived FROM those literals —
    /// can never disagree. What the pin buys, measured: a
    /// revert to the frame shape whose author does not re-run
    /// `extract-keys` reds HERE and nowhere else in the suite,
    /// and under an English pin would have passed all five
    /// clauses (`guard-prover`, 2026-09-06). `label`, the
    /// English the classifier
    /// persists (`KeyBinding.label`), is checked in the same
    /// pass: it is authored a second time per row, and nothing
    /// else holds the two equal.
    @Test("the rows on screen use those keys")
    func theRowsOnScreenUseThoseKeys() throws {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select("en") }
        let catalogs = try Self.catalogs()
        let english = try #require(catalogs["en"])
        let german = try #require(catalogs["de"])
        let families = [
            ("move", KeybindingCatalog.moveToTrackRows),
            ("swap", KeybindingCatalog.trackSwapRows),
        ]
        var checked = 0
        for (family, rows) in families {
            #expect(rows.count == 2)
            for step in ["prev", "next"] {
                let row = try #require(
                    rows.first { $0.lua.contains("\"\(step)\"") },
                    "\(family): no row for \(step)"
                )
                let key = try #require(
                    Self.rowKeys.first {
                        $0.family == family && $0.step == step
                    }?.key
                )
                #expect(row.resolvedLabel == german[key])
                #expect(row.label == english[key])
                checked += 1
            }
        }
        #expect(checked == Self.rowKeys.count)
    }
}
