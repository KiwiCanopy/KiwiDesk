import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A setting that skips Save says so (#3218). The subject is the
/// write, `setAppWide`: every GUI file holding one draws the note
/// — a card through `SettingsSection`'s `liveNote:`, a row through
/// one `LiveSettingCaption()` per write — or is named here with
/// the file that draws it, which is then held to drawing it.
///
/// What this trades: a card file is checked for ONE `liveNote:`,
/// so a second card added to that file without it passes; and a
/// live row written through any other door (a defaults write, a
/// Core verb) is unseen. Both are review's (gui.md).
@Suite("Live setting note (#3218)")
struct LiveSettingNoteTests {
    /// Writers with no row of their own, and why.
    private static let rowless: [String: String] = [
        "SettingsModel+AppWide.swift": "the door every row calls",
        "SettingsModel+Lenses.swift": "lenses save through Save",
    ]
    /// Writers whose note another file draws: that file.
    private static let notedBy: [String: String] = [
        "SpaceSwitchCard+Rows.swift": "SpaceSwitchCard.swift",
        // General's card carries the note as its title.
        "GeneralSection+AppWide.swift": "SettingsCatalog+WholeApp.swift",
    ]

    private func sources() throws -> [String: String] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var out: [String: String] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            out[url.lastPathComponent] = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            ).filter { !$0.isWhitespace }
        }
        return out
    }

    private func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("every app-wide writer draws the note, or names who does")
    func writersDrawTheNote() throws {
        let files = try sources()
        #expect(files.count > 50)
        let writers = files.filter { $0.value.contains("setAppWide") }
        #expect(writers.count >= 10)
        for (name, text) in writers {
            if Self.rowless[name] != nil { continue }
            if let drawer = Self.notedBy[name] {
                let other = try #require(
                    files[drawer],
                    Comment(rawValue: drawer)
                )
                #expect(
                    other.contains("liveNote:")
                        || other.contains(
                            "\"general.applies_immediately.title\""
                        ),
                    Comment(rawValue: "\(name) → \(drawer)")
                )
                continue
            }
            let writes = count("setAppWide{", in: text)
            let captions = count("LiveSettingCaption()", in: text)
            #expect(
                text.contains("liveNote:") || captions == writes,
                Comment(rawValue: "\(name): \(captions) of \(writes)")
            )
        }
        // An exemption for a file that no longer writes is stale.
        let named = Set(Self.rowless.keys).union(Self.notedBy.keys)
        #expect(named.isSubset(of: Set(writers.keys)))
    }

    /// The card slot takes the note and nothing else, so the
    /// secondary ink keeps meaning one thing.
    @Test("the card slot holds the note, or Never dimmed's variant")
    func cardSlotHoldsOnlyTheNote() throws {
        var values: [String: Int] = [:]
        // The slot's own declaration is no caller.
        for (name, text) in try sources()
        where name != "SettingsSection.swift" {
            for piece in text.components(separatedBy: "liveNote:")
                .dropFirst()
            {
                let value = String(piece.prefix { $0 != ")" && $0 != "," })
                values[value, default: 0] += 1
            }
        }
        #expect(
            Set(values.keys) == [
                "LiveSettingNote.text",
                "spaceTransitionLuaOwned?nil:LiveSettingNote.text",
                "KiwiVisionLensWords.neverDimmedCaption",
            ],
            Comment(rawValue: "\(values)")
        )
        #expect(values["LiveSettingNote.text"] == 4)
    }

    /// General's title is the note as a second key, so the two are
    /// held equal in every catalog, less the final stop.
    @Test("General's card title is the note, in every catalog")
    func generalTitleIsTheNote() throws {
        let locales = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let catalogs = try FileManager.default
            .contentsOfDirectory(atPath: locales.path)
            .filter { $0.hasSuffix(".json") }
        #expect(catalogs.count >= 11)
        for name in catalogs {
            let data = try Data(
                contentsOf: locales.appendingPathComponent(name)
            )
            let map = try #require(
                try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                Comment(rawValue: name)
            )
            let note = try #require(
                map["settings.applies_at_once"] as? String,
                Comment(rawValue: name)
            )
            let title = try #require(
                map["general.applies_immediately.title"] as? String,
                Comment(rawValue: name)
            )
            let stops: Set<Character> = [".", "。"]
            let bare =
                note.last.map(stops.contains) == true
                ? String(note.dropLast()) : note
            #expect(title == bare, Comment(rawValue: name))
        }
    }

    /// On a profile's page the live card comes last (#3218), and
    /// an unmounted card is rows nobody can reach.
    @Test("the Space switch card is mounted once, after Animations")
    func liveCardComesLast() throws {
        let section = try #require(try sources()["LooksSection.swift"])
        #expect(count("SpaceSwitchCard(model:", in: section) == 1)
        let motion = try #require(section.range(of: "MotionCard(model:"))
        let live = try #require(
            section.range(of: "SpaceSwitchCard(model:")
        )
        #expect(motion.upperBound < live.lowerBound)
        // Nothing is mounted after it.
        #expect(!section[live.upperBound...].contains("(model:model)"))
    }

    /// One sentence: the drawn text is the catalog's, so a reworded
    /// literal reds here and not only in lint.
    @Test("the note's English is the catalog's")
    @MainActor
    func noteIsTheCatalogs() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales/en.json"
            )
        let map = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url))
                as? [String: Any]
        )
        #expect(
            LiveSettingNote.text
                == map["settings.applies_at_once"] as? String
        )
    }
}
