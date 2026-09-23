import Foundation
import Testing

/// The Profiles row's screen-setup line is DRAWN (#1530): a
/// surfacing branch ends in an `if` inside a `body`, which every
/// behaviour suite passes whether or not it was written
/// (gui.md ▸ consulting a resolver is not drawing what it
/// answered). Needles are keyed on use sites over stripped source.
@Suite("Profiles screen-setup line is wired (#1530)")
struct ScreenSetupWiringTests {
    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/\(file)"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        #expect(!text.isEmpty)
        return text
    }

    @Test("Each profile row draws its setups and the counted default")
    func rowDrawsTheLine() throws {
        let row = try source("ProfilesSection.swift")
        #expect(row.occurrences(of: "screenSetupsLine(summary)") == 1)
        #expect(
            row.occurrences(of: "BadgeChip(label: defaultBadge(") == 1
        )
    }

    @Test("Dormant, collapsed and inline branches each draw")
    func branchesDraw() throws {
        let line = try source("ProfilesSection+ScreenSetups.swift")
        for needle in [
            "if summary.isDormant {\n                Text(dormantCaption(",
            "summary.sets.count > Self.inlineLimit {\n"
                + "                collapsedSetups(summary)",
            "setupChip(\n                        summary.sets[index]",
            "            addSetupMenu(summary)\n        }",
            "model.claimScreenSetup(",
        ] {
            #expect(
                line.occurrences(of: needle) == 1,
                Comment(rawValue: "not drawn: \(needle)")
            )
        }
    }
}
