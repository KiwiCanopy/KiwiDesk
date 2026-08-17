import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A preset summary names no layout MODE (#859).
///
/// Three of them did — "IDE stack", "scrolling docs", "a deep-work
/// monocle Space" — and ten catalogs then translated those words
/// inconsistently: `de` shipped "IDE-Stapel" and "scrollende
/// Dokumentation" beside pickers reading "Stack" and "Scrolling",
/// while keeping "Monocle" in the very next key. One word
/// translated, the next kept, inside one three-key set.
///
/// **No content guard could see it and none can be made to.**
/// `untranslated_mode_names` fires on the opposite polarity — a
/// locale that translated its picker keeping the English name in
/// prose — and `de` has English pickers with translated prose. So
/// the fix is not a better predicate over the translations; it is
/// that the English stops naming layouts, which removes the class.
/// This is what keeps it removed.
///
/// Reads the shipped `en.json` deliberately, the way
/// `LocalizationModeNamePolicyTests` does: a policy about the
/// corpus asserted only over fixtures the test wrote itself is
/// unfalsifiable. Scoped to ENGLISH because that is where the rule
/// binds (4b's audit: "one concept, one word" binds the English
/// author first) and because several mode names are ordinary
/// English words a translation may legitimately contain.
@Suite("Preset summary vocabulary")
struct PresetSummaryVocabularyTests {
    private func catalog() throws -> [String: String] {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales/en.json"
            )
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        return try #require(raw as? [String: String])
    }

    /// The ban list, DERIVED from the catalog's own mode names
    /// rather than seven strings typed here — a hand-listed copy
    /// would agree with the corpus the day it was written and stop
    /// guarding the day a mode is renamed or added
    /// (rule-authoring.md ▸ a number-pin must derive).
    private func modeNames(
        _ catalog: [String: String]
    ) throws -> [String] {
        let names = try LayoutMode.allCases.map { mode in
            try #require(
                catalog["layout.\(mode.rawValue).name"],
                "layout.\(mode.rawValue).name is missing from en"
            )
            .lowercased()
        }
        #expect(names.count == LayoutMode.allCases.count)
        return names
    }

    private func summaries(
        _ catalog: [String: String]
    ) -> [String: String] {
        catalog.filter {
            $0.key.hasPrefix("presets.")
                && $0.key.hasSuffix(".summary")
        }
    }

    /// Tokenised rather than substring-matched: "Monitor" contains
    /// no mode name but "monitoring" would trip a naive
    /// `contains`, and "stacked" is the word actually at issue.
    private func words(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
        )
    }

    @Test("no preset summary names a layout mode")
    func summariesNameNoMode() throws {
        let catalog = try catalog()
        let banned = try modeNames(catalog)
        let summaries = summaries(catalog)

        // Non-empty before asserting anything about it: a scan
        // that matched nothing passes for having found no
        // violations (rule-authoring.md).
        #expect(summaries.count >= StandardProfiles.workflows.count)
        #expect(!banned.isEmpty)

        for (key, english) in summaries {
            let used = words(english)
            for name in banned {
                #expect(
                    !used.contains(name),
                    Comment(
                        rawValue:
                            "\(key) names the layout '\(name)' in "
                            + "prose — layouts are named where they "
                            + "are drawn (the preview sheet), "
                            + "through layout.*.name, which every "
                            + "catalog already renders under a "
                            + "pinned policy"
                    )
                )
            }
        }
    }

    /// The stem case the tokeniser is for, pinned so a future
    /// "stacked"/"scrolling" cannot slip back in past a matcher
    /// that only looks for the exact noun.
    @Test("the three re-authored summaries carry no mode stem")
    func reauthoredSummariesCarryNoStem() throws {
        let catalog = try catalog()
        let stems = ["stack", "stacked", "scrolling", "monocle"]
        for key in [
            "presets.developer.summary",
            "presets.focus_stack.summary",
            "presets.minimalist.summary",
        ] {
            let english = try #require(catalog[key])
            let used = words(english)
            for stem in stems {
                #expect(!used.contains(stem), Comment(rawValue: key))
            }
        }
    }

    /// The other half of #859's string work: the two summaries that
    /// said "the main display" sat directly above an outline
    /// labelled "Main screen". One surface, one noun.
    ///
    /// This does NOT claim the repo settled screen vs display vs
    /// monitor — `en.json` still uses all three and that is an
    /// owner ruling plus a catalog-wide sweep, deliberately out of
    /// this change. It claims the Presets surface agrees with
    /// itself.
    @Test("the presets surface says screen, not display")
    func presetsSurfaceSaysScreen() throws {
        let catalog = try catalog()
        let surface =
            summaries(catalog)
            .merging(
                catalog.filter {
                    $0.key.hasPrefix("presets.screen_name.")
                }
            ) { first, _ in first }
        #expect(surface.count > StandardProfiles.workflows.count)
        for (key, english) in surface {
            #expect(
                !words(english).contains("display"),
                Comment(
                    rawValue:
                        "\(key) says 'display' on a surface whose "
                        + "own screen label says 'Main screen'"
                )
            )
        }
    }
}
