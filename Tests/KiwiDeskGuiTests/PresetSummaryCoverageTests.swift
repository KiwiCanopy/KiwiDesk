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
    func summariesAreTranslated() {
        // Pinned to a complete non-English locale: if a preset's
        // copy were hardcoded rather than keyed, it would read
        // identically here and in English. This is what would
        // have caught the Starter rungs before they shipped.
        LocalizationManager.shared.select("en")
        let english = StandardProfiles.all.map(\.displaySummary)
        LocalizationManager.shared.select("de")
        defer { reset() }
        let german = StandardProfiles.all.map(\.displaySummary)
        for (index, layout) in StandardProfiles.all.enumerated() {
            let unkeyed =
                "\(layout.name) (\(layout.screenCount) screen) "
                + "reads the same in en and de — its summary "
                + "is not going through a catalog key"
            #expect(
                english[index] != german[index],
                Comment(rawValue: unkeyed)
            )
        }
    }
}
