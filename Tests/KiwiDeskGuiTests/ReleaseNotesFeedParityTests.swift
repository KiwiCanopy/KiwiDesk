import Foundation
import Testing

@testable import KiwiDesk

/// The window's copy of the feed contract, held to the scripts
/// that write it (#1542; packaging-and-release.md ▸ the
/// `kiwidesk:notes` paragraph): the element NAME, the formats it
/// reads, and the section types it names. Each is read off a real
/// `appcast-sync` run or the scripts' own tables, never a literal
/// typed here — a renamed element empties every shipped window,
/// and a type the window does not name falls back to English.
@Suite("Release notes feed parity (#1542)")
struct ReleaseNotesFeedParityTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let tag = "v9999.3.0"

    private static func script(_ name: String) -> String {
        root.appendingPathComponent("scripts").appendingPathComponent(name)
            .path
    }

    /// `changelog-sync`'s `SECTION_TYPES`, as the script defines it.
    private static func scriptTypes() throws
        -> [(title: String, type: String)]
    {
        let run = try GuiScriptFixture.python([
            "-c",
            "import json, runpy, sys; "
                + "g = runpy.run_path(sys.argv[1]); "
                + "print(json.dumps(g['SECTION_TYPES']))",
            script("changelog-sync"),
        ])
        #expect(run.status == 0, "\(run.stderr)")
        let pairs = try #require(
            try JSONSerialization.jsonObject(with: Data(run.stdout.utf8))
                as? [[String]]
        )
        return pairs.map { ($0[0], $0[1]) }
    }

    private static func write(_ object: Any) throws -> URL {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("notes-parity-\(UUID()).json")
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        return file
    }

    /// A feed rendered by `appcast-sync` over one release carrying
    /// a section of every type `changelog-sync` knows.
    private static func feed(
        types: [(title: String, type: String)]
    ) throws -> XMLDocument {
        let version = String(tag.dropFirst())
        let archive = "KiwiDesk-\(version).zip"
        func asset(_ name: String, size: Int) -> [String: Any] {
            [
                "name": name,
                "size": size,
                "browser_download_url":
                    "https://github.com/KiwiCanopy/KiwiDesk/releases"
                    + "/download/\(tag)/\(name)",
                "url": "https://api.github.com/assets/9",
            ]
        }
        let release: [String: Any] = [
            "tag_name": tag,
            "published_at": "2026-09-24T10:00:00Z",
            "draft": false,
            "edsig": Data(repeating: 0x41, count: 64)
                .base64EncodedString(),
            "assets": [
                asset(archive, size: 9_123_456),
                asset("\(archive).edsig", size: 89),
            ],
        ]
        let notes: [String: Any] = [
            "generated_by": "ReleaseNotesFeedParityTests",
            "releases": [
                [
                    "tag": tag,
                    "version": version,
                    "summary": "A summary.",
                    "sections": types.map {
                        [
                            "title": $0.title, "type": $0.type,
                            "items": ["An entry."],
                        ]
                    },
                ]
            ],
        ]
        let releases = try write([release])
        let notesFile = try write(notes)
        defer {
            try? FileManager.default.removeItem(at: releases)
            try? FileManager.default.removeItem(at: notesFile)
        }
        let run = try GuiScriptFixture.python([
            script("appcast-sync"), "--all",
            "--releases", releases.path,
            "--notes", notesFile.path,
            "--output", "-",
        ])
        #expect(run.status == 0, "\(run.stderr)")
        return try XMLDocument(xmlString: run.stdout)
    }

    /// The element is found under the window's name — the key
    /// Sparkle files it by — and decodes: its format is one the
    /// window reads, and every type arrives.
    @Test("the window reads the element the generator writes")
    func windowReadsTheFeed() throws {
        let types = try Self.scriptTypes()
        #expect(!types.isEmpty)
        let doc = try Self.feed(types: types)
        let children = try doc.nodes(forXPath: "//item/*")
        let element = children.first { $0.name == ReleaseNotes.element }
        let text = try #require(
            element?.stringValue,
            .init(
                rawValue: "no <\(ReleaseNotes.element)> in the item; "
                    + "it carries: "
                    + children.compactMap(\.name).joined(separator: ", ")
            )
        )
        let notes = try #require(
            ReleaseNotes.decode(text),
            "the generator's format is not one the window reads"
        )
        #expect(notes.sections.map(\.type) == types.map(\.type))
    }

    /// Every type the grammar knows is named by the window in the
    /// reader's language, and the window names no retired one.
    @Test("the window names every section type the grammar has")
    func windowNamesEveryType() throws {
        let script = Set(try Self.scriptTypes().map(\.type))
        let window = Set(ReleaseNoteKind.allCases.map(\.rawValue))
        #expect(script == window)
    }
}
