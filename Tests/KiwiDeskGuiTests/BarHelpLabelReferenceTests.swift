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

    /// `helpKey`'s English must contain the English of every
    /// label key it claims to point at.
    private func expectReferences(
        _ helpKey: String,
        _ labelKeys: [String]
    ) throws {
        let catalog = try english
        let help = try #require(
            catalog[helpKey],
            "missing help key: \(helpKey)"
        )
        for labelKey in labelKeys {
            let label = try #require(
                catalog[labelKey],
                "missing label key: \(labelKey)"
            )
            #expect(
                help.contains(label),
                Comment(
                    rawValue:
                        "\(helpKey) does not name \"\(label)\" "
                        + "(\(labelKey))"
                )
            )
        }
    }

    @Test("App Bar symbol-style help names its colour rows")
    func appBarIconSourceHelpNamesRows() throws {
        try expectReferences(
            "app_bar.icon_source.help",
            [
                "app_bar.color.item",
                "app_bar.color.active_item",
                "app_bar.color.hover_item",
            ]
        )
    }

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
