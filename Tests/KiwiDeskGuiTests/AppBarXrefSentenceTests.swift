import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The App Bar cross-reference under the Monocle and Scrolling
/// layout cards is a whole localized sentence per bar state, one
/// key per resulting sentence (#1287). The obligation — an
/// interpolated value must not have to agree with the sentence
/// it lands in — is `.claude/rules/localization.md`'s to argue;
/// this is #1110's shape one part of speech over, and the suite
/// copies `TrackRowSentenceTests`.
///
/// The one specifier each sentence keeps is the destination
/// link (`CrossReferenceRow.linkSlot`), a name that agrees with
/// nothing. The state word is what the frame shape interpolated,
/// and a second specifier in a shipped value is that frame back.
///
/// `.serialized`, and each body pins its own locale: the
/// consumer clause moves the process-wide `LocalizationManager`
/// (tests.md, #740), restoring `"en"` for the reason
/// `DesktopAwayRowTests` carries.
@Suite("App Bar cross-reference sentences (#1287)", .serialized)
@MainActor
struct AppBarXrefSentenceTests {
    /// The four sentence keys, by hosting layout and bar state.
    private static let rowKeys: [(mode: LayoutMode, on: Bool, key: String)] =
        [
            (.monocle, true, "monocle.app_bar_xref_on"),
            (.monocle, false, "monocle.app_bar_xref_off"),
            (.scrolling, true, "scroll_grid.app_bar_xref_on"),
            (.scrolling, false, "scroll_grid.app_bar_xref_off"),
        ]

    /// The two frames the participle went into. A NEGATIVE
    /// clause: their return is exactly the regression, and
    /// `common.on` / `common.off` stay — their standalone
    /// readouts are not this defect.
    private static let retiredKeys = [
        "monocle.app_bar_xref_state",
        "scroll_grid.app_bar_xref_state",
    ]

    private static let localesDirectory = SourceScan.repoRoot(
        from: #filePath
    )
    .appendingPathComponent("Sources")
    .appendingPathComponent("KiwiDeskCore")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Locales")

    /// Every shipped catalog, decoded, nothing skipped — a file
    /// there that is not a flat catalog is `SettingKeyLocaleTests`'
    /// to name, and reading past it would let a stray worksheet
    /// stand in for a missing translation.
    private static func catalogs() throws -> [String: [String: String]] {
        let files = try FileManager.default.contentsOfDirectory(
            at: localesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        var out: [String: [String: String]] = [:]
        for file in files {
            let data = try Data(contentsOf: file)
            out[file.deletingPathExtension().lastPathComponent] =
                try JSONDecoder().decode(
                    [String: String].self,
                    from: data
                )
        }
        // Floored once: a scanning clause over an empty fixture
        // passes for having found nothing (rule-authoring.md).
        #expect(out.count > 1)
        #expect(out["en"] != nil)
        return out
    }

    /// Every locale answers all four sentences. The frame shape
    /// needed one frame plus a shared word per layout; a merge
    /// that skipped one state would fall back to English under a
    /// card whose every other row is translated.
    @Test("every locale carries all four sentences")
    func everyLocaleCarriesTheFourSentences() throws {
        for (locale, catalog) in try Self.catalogs() {
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

    /// Each sentence interpolates the link and nothing else: the
    /// slot's specifier once, and no second one — the second is
    /// where the state word used to land.
    @Test("each sentence interpolates only the link")
    func eachSentenceInterpolatesOnlyTheLink() throws {
        for (locale, catalog) in try Self.catalogs() {
            for row in Self.rowKeys {
                guard let value = catalog[row.key] else { continue }
                #expect(
                    value.components(separatedBy: "%1$@").count == 2,
                    Comment(
                        rawValue: "\(locale): \(row.key) places its "
                            + "link other than once (\(value))"
                    )
                )
                #expect(
                    !value.contains("%2$"),
                    Comment(
                        rawValue: "\(locale): \(row.key) interpolates "
                            + "a second value (\(value))"
                    )
                )
            }
        }
    }

    /// The frame shape is gone from every catalog. This is the
    /// clause that answers a real revert: the call site coming
    /// back re-mints those keys, and nothing else here watches a
    /// key by the name it used to have.
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

    /// Four distinct sentences per locale — the two layouts
    /// differ, and so do the two states. One value serving both
    /// states is a state word dropped rather than inlined.
    @Test("the four sentences are four different sentences")
    func theFourSentencesAreDistinct() throws {
        for (locale, catalog) in try Self.catalogs() {
            let values = Self.rowKeys.compactMap { catalog[$0.key] }
            #expect(values.count == Self.rowKeys.count)
            #expect(
                Set(values).count == values.count,
                "\(locale): sentences share a value \(values)"
            )
        }
    }

    /// The CONSUMER clause: the prose the card renders is the
    /// catalog's sentence with the link in its slot, for both
    /// hosting layouts in both states.
    ///
    /// Pinned to `de`, never `"en"`: `effectiveLocale`
    /// short-circuits an explicit `"en"` to `nil`, so every `L()`
    /// returns its own call-site literal, and comparing that
    /// against `en.json` — derived FROM those literals — can
    /// never disagree. A revert to the frame shape whose author
    /// does not re-run `extract-keys` reds here and nowhere else
    /// in the suite (`TrackRowSentenceTests` measured the same).
    @Test("the prose on screen is those sentences")
    func theProseOnScreenIsThoseSentences() throws {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select("en") }
        let german = try #require(try Self.catalogs()["de"])
        var checked = 0
        for row in Self.rowKeys {
            let prose = try #require(
                LayoutCardText.appBarState(row.mode, on: row.on),
                "\(row.mode) on=\(row.on) renders no sentence"
            )
            let expected = try #require(german[row.key])
                .replacingOccurrences(
                    of: "%1$@",
                    with: CrossReferenceRow.linkSlot
                )
            #expect(
                prose == expected,
                "\(row.mode) on=\(row.on): \(prose)"
            )
            checked += 1
        }
        #expect(checked == Self.rowKeys.count)
    }
}
