import Foundation
import Testing

/// A help string that names other controls must name them by
/// the labels those controls actually ship (#519).
///
/// The App Bar's "App symbol style" help pointed at "Text,
/// Active text, and Hover text" while the rows had been
/// relabelled to "Item / Active item / Hover item" — a shipped
/// user-facing string directing the user to controls that did
/// not exist under those names, left behind by the bars
/// colour-model merge.
///
/// This is about to matter more, not less: the #406 vocabulary
/// convergence (R6) will rename more of these labels, and a
/// rename that updates the row but not the sentence pointing at
/// it re-creates the exact defect. Reading both sides out of
/// `en.json` means the guard tracks whatever the labels become.
@Suite("Bar help strings name real controls")
struct BarHelpLabelReferenceTests {
    private var english: [String: String] {
        get throws {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // KiwiDeskGuiTests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // repo root
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/Resources/Locales/"
                        + "en.json"
                )
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            return decoded
        }
    }

    // `app_bar.icon_source.help` was this suite's founding case
    // and no longer belongs to it. It now INTERPOLATES its four
    // labels rather than spelling them (#818), so the property
    // this suite checks by matching text is true of it by
    // construction, in every locale rather than only in English
    // — and the matching test had to be retired rather than
    // adapted, because it demanded the literal labels be present
    // and would now fail on the fix. Its floor lives in
    // `InterpolatedLabelTests.converted`, which reds if the
    // frame goes back to literal text.
    //
    // The check below stays because it is a genuinely different
    // obligation: the Space Bar twin names its colours by the
    // shared NOUN rather than by listing the rows, so there is
    // no label to interpolate and text-matching is the only
    // thing that can hold it.

    /// The Space Bar twin names its colours generically rather
    /// than listing them, so only the shared noun is pinned —
    /// but it is pinned against the same row label, so a rename
    /// of "Item" still surfaces here.
    @Test("Space Bar symbol-style help uses the row's noun")
    func spaceBarIconSourceHelpUsesRowNoun() throws {
        let catalog = try english
        let help = try #require(
            catalog["space_bar.icon_source.help"]
        )
        let item = try #require(catalog["space_bar.color.item"])
        #expect(
            help.lowercased().contains(item.lowercased()),
            Comment(
                rawValue:
                    "space_bar.icon_source.help does not use "
                    + "the \"\(item)\" vocabulary"
            )
        )
    }
}
