import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Key sequences card's empty state and columns (#3649): an
/// empty card says so in one sentence and draws no row stack; a
/// sequence recorder carries its badge and sides menu after the
/// well, drawn only when used, so no blank column sits between
/// the fold and the well; and both Add buttons stand in the well
/// column of the level they add to. Source needles, whitespace
/// stripped, since a SwiftUI layout leaves nothing a headless
/// test can read.
@Suite("Key sequence card layout (#3649)")
@MainActor
struct KeySequenceCardLayoutTests {
    private static let card =
        "Sources/KiwiDesk/Settings/Sections/KeySequencesCard.swift"
    private static let sequences =
        "Sources/KiwiDesk/Settings/Components/Keybindings/Sequences/"
    private static let recorder =
        "Sources/KiwiDesk/Settings/Components/Keybindings/Recorder/"

    private static func flat(_ path: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        )
        .filter { !$0.isWhitespace }
        #expect(!text.isEmpty)
        return text
    }

    @Test("an empty card draws its sentence in place of the rows")
    func emptySentence() throws {
        LocalizationManager.shared.select("en")
        #expect(
            KeySequencesCard.empty
                == "No key sequence has been set up yet. Add one and "
                + "its first chord opens a panel of the keys that come "
                + "next."
        )
        let card = try Self.flat(Self.card)
        #expect(
            card.contains(
                "ifsequences.isEmpty{Text(Self.empty)"
                    + ".font(.caption).foregroundStyle(.secondary)"
            )
        )
        #expect(card.contains("}else{sequenceRows(catalog)}"))
        #expect(card.contains("\"shortcuts.sequence.card_empty\""))
    }

    @Test("every catalog carries the empty sentence")
    func catalogsCarryIt() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let files = try FileManager.default
            .contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".json") }
        #expect(files.contains("en.json"))
        for file in files {
            let data = try Data(
                contentsOf: dir.appendingPathComponent(file)
            )
            let map = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            #expect(
                map["shortcuts.sequence.card_empty"]?.isEmpty == false,
                Comment(rawValue: "\(file) lacks the empty sentence")
            )
        }
    }

    @Test("a sequence recorder draws its marks after the well, if used")
    func marksTrail() throws {
        let field = try Self.flat(Self.recorder + "KeyRecorderField.swift")
        #expect(
            field.contains(
                "if!marksTrailing{conflictBadgesidesSlot}"
                    + "recordButtonclearButton"
                    + "ifmarksTrailing{trailingMarks}"
            )
        )
        let sides = try Self.flat(
            Self.recorder + "KeyRecorderField+Sides.swift"
        )
        #expect(sides.contains("!=nil{sidesSlot}"))
        #expect(sides.contains("ifconflictSentence!=nil{conflictBadge}"))
        let row = try Self.flat(
            Self.sequences + "SequenceNodeRow+Recorder.swift"
        )
        #expect(row.contains("marksTrailing:true"))
    }

    @Test("both Add buttons stand in their level's well column")
    func addButtonsInWellColumn() throws {
        // The well sits one fold slot and the row's spacing in.
        #expect(
            SettingsMetrics.shortcutTextIndent
                == SequenceNodeRow.foldSlot + 8
        )
        let row = try Self.flat(Self.sequences + "SequenceNodeRow.swift")
        #expect(row.contains("ShortcutKeyRow(spacing:8)"))
        let chipThenIndent =
            ".settingsActionButton()"
            + ".padding(.leading,SettingsMetrics.shortcutTextIndent)"
        #expect(row.contains(chipThenIndent + ".accessibilityHint(name)"))
        let card = try Self.flat(Self.card)
        #expect(card.contains(chipThenIndent))
    }
}
