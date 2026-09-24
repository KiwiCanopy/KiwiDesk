import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The update window's "everything since your version" merge
/// (#1542 ruling) and the feed document's growth rules
/// (packaging-and-release.md ▸ the `kiwidesk:notes` paragraph).
@Suite("Update notes digest (#1542)")
struct UpdateNotesDigestTests {
    private static func notes(
        _ sections: [(String, [String])],
        summary: String = "Summary.",
        heads: String? = nil,
        format: Int = 1,
        extra: [String: Any] = [:]
    ) -> String {
        var document: [String: Any] = [
            "format": format,
            "summary": summary,
            "sections": sections.map { type, items in
                ["type": type, "title": type.capitalized, "items": items]
            },
        ]
        if let heads { document["heads"] = heads }
        document.merge(extra) { $1 }
        let data = try! JSONSerialization.data(withJSONObject: document)
        return String(decoding: data, as: UTF8.self)
    }

    private static func compare(_ a: String, _ b: String)
        -> ComparisonResult
    {
        a.compare(b, options: .numeric)
    }

    private static func digest(
        _ sources: [UpdateNotesDigest.Source],
        installed: String = "2.0.0",
        offered: String = "2.1.0"
    ) -> UpdateNotesDigest? {
        UpdateNotesDigest.make(
            sources: sources,
            installed: installed,
            offered: offered,
            compare: compare
        )
    }

    // MARK: - The document

    @Test("unknown keys are ignored")
    func unknownKeysIgnored() {
        let text = Self.notes(
            [("new", ["A"])],
            extra: ["future": ["x": 1]]
        )
        #expect(ReleaseNotes.decode(text)?.sections.count == 1)
    }

    @Test("an unknown format or malformed JSON reads as nil")
    func unreadableIsNil() {
        #expect(ReleaseNotes.decode(Self.notes([], format: 99)) == nil)
        #expect(ReleaseNotes.decode("{not json") == nil)
        #expect(ReleaseNotes.decode(nil) == nil)
    }

    // MARK: - One version

    @Test("one version behind: groups in the fixed order, no labels")
    func oneVersion() throws {
        let digest = try #require(
            Self.digest([
                .init(
                    version: "2.1.0",
                    notes: Self.notes([
                        ("scripting", ["S"]),
                        ("fixed", ["F1", "F2"]),
                        ("new", ["N"]),
                        ("improved", ["I"]),
                    ])
                )
            ])
        )
        #expect(
            digest.groups.map(\.type)
                == ["new", "improved", "fixed", "scripting"]
        )
        #expect(digest.total == 5)
        #expect(!digest.spansVersions)
        #expect(digest.unreadable.isEmpty)
    }

    /// A type this build does not know is shown under its title,
    /// ahead of Lua & CLI, which stays last.
    @Test("an unknown type is a group under its title")
    func unknownTypeGroups() throws {
        let digest = try #require(
            Self.digest([
                .init(
                    version: "2.1.0",
                    notes: Self.notes([
                        ("scripting", ["S"]),
                        ("security", ["X"]),
                        ("new", ["N"]),
                    ])
                )
            ])
        )
        #expect(
            digest.groups.map(\.type) == ["new", "security", "scripting"]
        )
        let other = try #require(digest.groups.first { $0.kind == nil })
        #expect(other.title == "Security")
    }

    @Test("unreadable offered notes fall back to the link")
    func offeredUnreadableFallsBack() {
        #expect(
            Self.digest([.init(version: "2.1.0", notes: nil)]) == nil
        )
        #expect(
            Self.digest([
                .init(version: "2.1.0", notes: Self.notes([], format: 2))
            ]) == nil
        )
    }

    // MARK: - Everything since your version

    @Test("skipped versions merge, labelled, newest first")
    func skippedVersionsMerge() throws {
        let digest = try #require(
            Self.digest(
                [
                    .init(
                        version: "2.0.1",
                        notes: Self.notes(
                            [("fixed", ["old fix"])],
                            summary: "Old.",
                            heads: "Old caution."
                        )
                    ),
                    .init(
                        version: "2.1.0",
                        notes: Self.notes(
                            [("fixed", ["new fix"]), ("new", ["N"])],
                            summary: "Newest.",
                            heads: "New caution."
                        )
                    ),
                    // The installed version and one older stay out.
                    .init(
                        version: "2.0.0",
                        notes: Self.notes([("new", ["installed"])])
                    ),
                    .init(
                        version: "1.4.0",
                        notes: Self.notes([("new", ["older"])])
                    ),
                ]
            )
        )
        #expect(digest.summary == "Newest.")
        #expect(digest.spansVersions)
        #expect(digest.versions == ["2.1.0", "2.0.1"])
        #expect(
            digest.cautions.map(\.version) == ["2.1.0", "2.0.1"]
        )
        let fixed = try #require(digest.groups.first { $0.type == "fixed" })
        #expect(
            fixed.entries
                == [
                    .init(text: "new fix", version: "2.1.0"),
                    .init(text: "old fix", version: "2.0.1"),
                ]
        )
        #expect(digest.total == 3)
    }

    /// A version the offer is not the newest of stays out: the
    /// window describes what installing gives you.
    @Test("a version newer than the offer stays out")
    func newerThanOfferStaysOut() throws {
        let digest = try #require(
            Self.digest([
                .init(version: "2.2.0", notes: Self.notes([("new", ["no"])])),
                .init(version: "2.1.0", notes: Self.notes([("new", ["yes"])])),
            ])
        )
        #expect(digest.groups.first?.entries.map(\.text) == ["yes"])
    }

    @Test("an unreadable skipped version drops alone")
    func unreadableSkippedDrops() throws {
        let digest = try #require(
            Self.digest([
                .init(version: "2.0.5", notes: "{broken"),
                .init(version: "2.1.0", notes: Self.notes([("new", ["N"])])),
            ])
        )
        #expect(digest.unreadable == ["2.0.5"])
        #expect(digest.versions == ["2.1.0"])
        #expect(!digest.spansVersions)
    }

    // MARK: - Disclosure

    @Test("the first group opens; Lua & CLI never does")
    func initialDisclosure() {
        func group(_ type: String) -> UpdateNotesDigest.Group {
            .init(type: type, title: type, entries: [])
        }
        #expect(
            UpdateNotesDisclosure.initiallyOpen([
                group("fixed"), group("scripting"),
            ]) == ["fixed"]
        )
        #expect(
            UpdateNotesDisclosure.initiallyOpen([group("scripting")])
                .isEmpty
        )
        #expect(UpdateNotesDisclosure.initiallyOpen([]).isEmpty)
    }
}

/// Entries carry their version in brackets only when the window
/// spans several versions (owner, 2026-09-24).
@MainActor
@Suite("Update notes entry version (#1542)", .serialized)
struct UpdateNotesEntryVersionTests {
    @Test("the version follows the entry in brackets, or not at all")
    func versionInBrackets() {
        LocalizationManager.shared.select("en")
        let labelled = UpdateNotesMarkdown.entry(
            "**A** fix.",
            version: "2.0.1"
        )
        #expect(String(labelled.characters) == "A fix. (2.0.1)")
        let plain = UpdateNotesMarkdown.entry("**A** fix.", version: nil)
        #expect(String(plain.characters) == "A fix.")
    }
}
