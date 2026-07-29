import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every shipped preset must render localized copy (#601).
///
/// This is the guard the boundary scan cannot be: `StandardLayout`
/// used to carry a `summary` String built in Core, and the three
/// Starter rungs — the presets that LEAD each screen count in the
/// list, so the first three a new user sees — had no case in
/// `displaySummary` and fell through to it. They rendered Core's
/// hardcoded English in all eleven locales. That string never went
/// near `L()`, so `CoreLocalizationBoundaryTests` could not have
/// seen it and `scripts/extract-keys` never put it in a catalog.
///
/// Two things now make it impossible rather than merely fixed:
/// Core no longer holds the copy at all (there is nothing to fall
/// back TO — an uncovered preset renders empty, not English), and
/// this suite fails on empty. A new preset is caught by whichever
/// bites first.
@Suite("Preset summary coverage", .serialized)
@MainActor
struct PresetSummaryCoverageTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    @Test("Every shipped preset renders a name and a summary")
    func everyPresetRendersCopy() {
        LocalizationManager.shared.select("en")
        defer { reset() }
        for layout in StandardProfiles.all {
            let summary = layout.displaySummary
            let missing =
                "\(layout.name) (\(layout.screenCount) screen) "
                + "has no localized summary — add a case to "
                + "StandardLayoutDisplay.displaySummary"
            #expect(
                !summary.isEmpty,
                Comment(rawValue: missing)
            )
            #expect(!layout.displayName.isEmpty)
        }
    }

    @Test("Each screen count's Starter reads differently")
    func starterRungsAreDistinct() {
        LocalizationManager.shared.select("en")
        defer { reset() }
        // All three rungs share one `name`, so the switch has to
        // discriminate on `screenCount`. A case that forgot the
        // `where` clause would silently give all three the
        // one-screen sentence.
        let rungs = StandardProfiles.all
            .filter { $0.name == StarterLadder.name }
            .map(\.displaySummary)
        #expect(rungs.count == 3)
        #expect(Set(rungs).count == 3)
    }

    @Test("Preset copy actually resolves through a catalog")
    func summariesAreKeyed() throws {
        // The defect this exists to catch is a summary written as
        // a plain literal instead of an `L()` key — which is how
        // the Starter rungs shipped untranslatable.
        //
        // Deliberately NOT "en and de differ". A preset added the
        // documented way (call site → extract-keys → translate
        // later) falls back to English in de by design, and
        // `drop-key --locale de` is the sanctioned repair for a
        // bad German string — both would have reddened that
        // formulation with a diagnosis that is simply false, and
        // it would have made presets the one family where a
        // half-translated locale is a test failure rather than
        // graceful degradation.
        //
        // `en.json` is generated from real `L()` call sites, so a
        // literal is absent from it by construction. That is the
        // precise question, and it does not touch any locale's
        // completeness.
        let english = try catalogValues(locale: "en")
        LocalizationManager.shared.select("en")
        defer { reset() }
        for layout in StandardProfiles.all {
            let rendered = layout.displaySummary
            // Resolve to a Bool first: passing the Set into the
            // expectation makes a failure print all 843 values.
            let isKeyed = english.contains(rendered)
            let unkeyed =
                "\(layout.name) (\(layout.screenCount) screen): "
                + "\"\(rendered)\" is not a value in en.json, so "
                + "it is a hardcoded literal rather than an L() key"
            #expect(isKeyed, Comment(rawValue: unkeyed))
        }
    }

    /// The shipped catalog for a locale, read from the resource
    /// the app itself loads.
    private func catalogValues(locale: String) throws -> Set<String> {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales/"
                    + locale + ".json"
            )
        let data = try Data(contentsOf: url)
        let map =
            try JSONSerialization.jsonObject(with: data)
            as? [String: String] ?? [:]
        return Set(map.values)
    }
}
