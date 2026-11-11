import Foundation
import Testing

@testable import KiwiDesk

/// A setting that skips Save says so (#3218): every GUI file that
/// writes an app-wide value draws `LiveSettingNote`, or is named
/// here with where its note is drawn instead. The write is the
/// subject, so a new live row with no note reds.
@Suite("Live setting note (#3218)")
struct LiveSettingNoteTests {
    /// Writers whose note is drawn by another file, and which.
    private static let notedElsewhere: [String: String] = [
        // The model's own door, which every row calls.
        "SettingsModel+AppWide.swift": "no row",
        // Lenses are app-wide but save through Save (ruled).
        "SettingsModel+Lenses.swift": "Save",
        // The whole card is live: its title is the note.
        "GeneralSection+AppWide.swift": "SettingsCatalog+WholeApp.swift",
        // The card says "in every profile and lens" of its list.
        "KiwiVisionNeverDimmedCard.swift": "its own caption",
        // Rows of a card that leads with the note.
        "SpaceSwitchCard+Rows.swift": "SpaceSwitchCard.swift",
    ]

    @Test("every app-wide writer draws the note, or is named")
    func writersDrawTheNote() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: root)
        #expect(files.count > 50)
        var writers: Set<String> = []
        var bare: Set<String> = []
        for url in files {
            let text = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            guard text.contains("setAppWide") else { continue }
            let name = url.lastPathComponent
            writers.insert(name)
            let noted =
                text.contains("LiveSettingNote.text")
                || text.contains("LiveSettingCaption()")
            if !noted && Self.notedElsewhere[name] == nil {
                bare.insert(name)
            }
        }
        #expect(writers.count >= 10)
        #expect(bare.isEmpty, Comment(rawValue: "\(bare.sorted())"))
        // An exemption for a file that no longer writes is stale.
        #expect(Set(Self.notedElsewhere.keys).isSubset(of: writers))
    }

    @Test("the card whose rows the model writes leads with the note")
    func cardsLeadWithTheNote() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        for path in [
            "Components/Looks/SpaceSwitchCard.swift",
            "Components/KiwiVision/KiwiVisionLevelsCard.swift",
        ] {
            let flat = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            ).filter { !$0.isWhitespace }
            #expect(
                flat.contains(
                    "caption:LiveSettingNote.text,captionProminent:true"
                ),
                Comment(rawValue: path)
            )
        }
    }
}
