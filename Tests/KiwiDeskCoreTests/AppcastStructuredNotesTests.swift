import Foundation
import Testing

/// The feed carries a typed release's notes as data beside the
/// HTML (#1542): one namespaced element holding JSON, which
/// KiwiDesk's own update window reads through Sparkle's
/// `propertiesDictionary` instead of parsing the HTML every 1.x
/// client still renders.
///
/// Read back with `XMLDocument`, the parser Sparkle's appcast
/// reader uses, and by the element's qualified name, the key
/// Sparkle files it under.
@Suite("Appcast structured notes (#1542)")
struct AppcastStructuredNotesTests {
    private static let tag = "v9999.2.0"

    private func feed(
        sections: [[String: Any]],
        heads: String? = nil
    ) throws -> XMLDocument {
        var entry: [String: Any] = [
            "tag": Self.tag,
            "version": "9999.2.0",
            "summary": "A summary.",
            "sections": sections,
        ]
        if let heads { entry["heads"] = heads }
        let notes = try AppcastFixture.write(
            [
                "generated_by": "AppcastStructuredNotesTests",
                "releases": [entry],
            ],
            label: "notes"
        )
        defer { try? FileManager.default.removeItem(at: notes) }
        let run = try AppcastFixture.render(
            [AppcastFixture.release(tag: Self.tag)],
            arguments: ["--all", "--notes", notes.path]
        )
        #expect(run.status == 0, "\(run.stderr)")
        return try XMLDocument(xmlString: run.stdout)
    }

    private func notesElement(_ doc: XMLDocument) throws -> XMLNode? {
        try doc.nodes(forXPath: "//item/*").first {
            $0.name == "kiwidesk:notes"
        }
    }

    private func decoded(_ doc: XMLDocument) throws -> [String: Any] {
        let node = try #require(try notesElement(doc))
        let text = try #require(node.stringValue)
        let object = try JSONSerialization.jsonObject(
            with: Data(text.utf8)
        )
        return try #require(object as? [String: Any])
    }

    /// `NOTES_FORMAT` as the script declares it, so a deliberate
    /// bump moves this test with it.
    private static func notesFormat() throws -> Int {
        let source = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("appcast-sync"),
            encoding: .utf8
        )
        let line = try #require(
            source.split(separator: "\n").first {
                $0.hasPrefix("NOTES_FORMAT = ")
            }
        )
        return try #require(
            Int(line.dropFirst("NOTES_FORMAT = ".count))
        )
    }

    @Test("a typed release carries its notes with each type")
    func typedNotesCarried() throws {
        let doc = try feed(
            sections: [
                ["title": "New", "type": "new", "items": ["**A**."]],
                ["title": "Lua & CLI", "type": "scripting", "items": ["B"]],
            ],
            heads: "Settings carry over."
        )
        let notes = try decoded(doc)
        #expect(notes["format"] as? Int == (try Self.notesFormat()))
        #expect(notes["summary"] as? String == "A summary.")
        #expect(notes["heads"] as? String == "Settings carry over.")
        let sections = notes["sections"] as? [[String: Any]] ?? []
        #expect(
            sections.map { $0["type"] as? String } == ["new", "scripting"]
        )
        #expect(sections.first?["items"] as? [String] == ["**A**."])
        // The HTML stays for every 1.x client.
        let description = try doc.nodes(forXPath: "//item/description")
        #expect(description.count == 1)
    }

    /// A release before 2.0.0 has free sections the window does
    /// not group, so its item carries the HTML alone.
    @Test("an untyped release carries no notes element")
    func untypedCarriesNone() throws {
        let doc = try feed(sections: [["title": "Things", "items": ["A"]]])
        // The lookup does reach this item, so the absence below
        // is the element's and not a broken query's.
        let children = try doc.nodes(forXPath: "//item/*").compactMap(\.name)
        #expect(children.contains("description"))
        #expect(try notesElement(doc) == nil)
    }

    /// `]]>` inside an entry would close the CDATA early and
    /// truncate the JSON; escaped, it round-trips unchanged.
    @Test("a CDATA terminator in an entry survives")
    func cdataTerminatorSurvives() throws {
        let doc = try feed(
            sections: [
                ["title": "Fixed", "type": "fixed", "items": ["a ]]> b"]]
            ]
        )
        let sections = try decoded(doc)["sections"] as? [[String: Any]]
        #expect(sections?.first?["items"] as? [String] == ["a ]]> b"])
    }
}
