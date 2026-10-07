import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Highlights tab's spotlight across skipped versions (#2038
/// ruling ▸ Mixed versions: rows win), pinned on
/// `UpdateNotesDigest.make` — the one home of the rule.
@Suite("Update notes spotlight (#2038)")
struct UpdateNotesSpotlightTests {
    private static func notes(
        summary: String,
        rows: [String] = [],
        heads: String? = nil
    ) -> String {
        var document: [String: Any] = [
            "format": 1,
            "summary": summary,
            "sections": [["type": "new", "title": "New", "items": ["N"]]],
            "spotlight": rows.map { ["title": $0, "line": "\($0) line."] },
        ]
        if let heads { document["heads"] = heads }
        let data = try! JSONSerialization.data(withJSONObject: document)
        return String(decoding: data, as: UTF8.self)
    }

    private static func digest(
        _ sources: [(String, String)],
        installed: String = "2.0.0"
    ) throws -> UpdateNotesDigest {
        try #require(
            UpdateNotesDigest.make(
                sources: sources.map { .init(version: $0.0, notes: $0.1) },
                installed: installed,
                offered: sources.map(\.0).max {
                    $0.compare($1, options: .numeric) == .orderedAscending
                } ?? "",
                compare: { $0.compare($1, options: .numeric) }
            )
        )
    }

    private static func titles(_ digest: UpdateNotesDigest) -> [String] {
        digest.spotlight.map(\.row.title)
    }

    private static func tags(_ digest: UpdateNotesDigest) -> [String?] {
        digest.spotlight.map(digest.tag)
    }

    @Test("a patch's prose introduces the older version's tagged rows")
    func patchProseOverOlderRows() throws {
        let digest = try Self.digest([
            ("2.1.0", Self.notes(summary: "Minor.", rows: ["A", "B"])),
            ("2.1.1", Self.notes(summary: "A round of fixes.")),
        ])
        #expect(digest.summary == "A round of fixes.")
        #expect(Self.titles(digest) == ["A", "B"])
        #expect(Self.tags(digest) == ["2.1.0", "2.1.0"])
    }

    @Test("newest rows over an older patch's prose: no prose")
    func newestRowsOverOlderProse() throws {
        let digest = try Self.digest(
            [
                ("2.1.1", Self.notes(summary: "A round of fixes.")),
                ("2.2.0", Self.notes(summary: "Intro.", rows: ["C"])),
            ],
            installed: "2.1.0"
        )
        #expect(digest.summary == "Intro.")
        #expect(Self.titles(digest) == ["C"])
    }

    @Test("the cap trims the oldest version's rows first")
    func capTrimsOldestFirst() throws {
        let digest = try Self.digest([
            ("2.1.0", Self.notes(summary: "Old.", rows: ["O1", "O2", "O3"])),
            ("2.2.0", Self.notes(summary: "New.", rows: ["N1", "N2"])),
        ])
        #expect(Self.titles(digest) == ["N1", "N2", "O1", "O2"])
        #expect(Self.tags(digest) == [nil, nil, "2.1.0", "2.1.0"])
    }

    @Test("a rowless minor stands alone: older rows dropped")
    func rowlessMinorStandsAlone() throws {
        let digest = try Self.digest([
            ("2.1.0", Self.notes(summary: "Old.", rows: ["A"])),
            ("2.2.0", Self.notes(summary: "Long minor prose.")),
        ])
        #expect(digest.summary == "Long minor prose.")
        #expect(digest.spotlight.isEmpty)
    }

    @Test("a single-version digest tags no row")
    func singleVersionUntagged() throws {
        let digest = try Self.digest(
            [("2.2.0", Self.notes(summary: "Intro.", rows: ["A", "B"]))],
            installed: "2.1.0"
        )
        #expect(Self.tags(digest) == [nil, nil])
    }

    @Test("every covered version's caution is kept")
    func cautionsKept() throws {
        let digest = try Self.digest([
            ("2.1.0", Self.notes(summary: "Old.", rows: ["A"], heads: "H1")),
            ("2.2.0", Self.notes(summary: "New.", rows: ["B"], heads: "H2")),
        ])
        #expect(digest.cautions.map(\.text) == ["H2", "H1"])
    }

    /// The rows are optional growth: a malformed list costs the
    /// version its rows, never its notes.
    @Test("a malformed spotlight reads as none")
    func malformedSpotlightIsNone() throws {
        let text = """
            {"format":1,"summary":"S.","sections":[],\
            "spotlight":[{"line":"no title"}]}
            """
        let notes = try #require(ReleaseNotes.decode(text))
        #expect(notes.spotlight.isEmpty)
        #expect(notes.summary == "S.")
    }

    @Test("a minor's trailing .0 is dropped from the row tag")
    func rowTagShortens() {
        #expect(UpdateNotesEnglish.rowTag("2.1.0") == " \u{00B7} 2.1")
        #expect(UpdateNotesEnglish.rowTag("2.1.1") == " \u{00B7} 2.1.1")
    }
}
