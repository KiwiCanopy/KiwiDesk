import Foundation
import Testing

@testable import KiwiDeskCore

/// The exported look file's format and credit (#1740): an export
/// states the format it was written in and its author beside the
/// look body; an older file crosses in memory, a newer one is
/// refused, and a gallery file imports with its credit.
@Suite("Look export format")
struct LookExportFormatTests {
    private func look() -> ShelfLook {
        ShelfLook(
            name: "Dusk",
            style: ["kiwishelf.thickness": .number(30)],
            colors: ["kiwishelf.fill_color": "#112233"]
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("an export states its format and credit beside the body")
    func exportCarriesFormatAndCredit() throws {
        var credited = look()
        credited.author = "Anna"
        credited.basedOn = LookCredit(name: "Night", author: "Maya")
        let data = try JSONEncoder().encode(LookExport(look: credited))
        let root = try object(data)
        #expect(root["format"] as? Int == LookDocument.currentFormat)
        #expect(root["author"] as? String == "Anna")
        let based = try #require(root["based_on"] as? [String: Any])
        #expect(based["name"] as? String == "Night")
        let body = try #require(root["look"] as? [String: Any])
        #expect(Set(body.keys) == ["name", "style", "colors"])
    }

    @Test("every field of a credited look survives export")
    func everyFieldRoundTrips() throws {
        var credited = look()
        credited.author = "Anna"
        credited.basedOn = LookCredit(
            name: "Night",
            author: "Maya",
            id: "night",
            removed: nil
        )
        let data = try JSONEncoder().encode(LookExport(look: credited))
        let back = try LookStore.importLook(data: data)
        #expect(back == credited.admitted)
    }

    @Test("a gallery file imports with its credit")
    func galleryFileImports() throws {
        let file = """
            {"format": \(LookDocument.currentFormat), "author": "Anna",
             "based_on": {"name": "Night", "author": "Maya",
                          "id": "night"},
             "look": {"name": "Dusk",
                      "style": {"kiwishelf.thickness": 30},
                      "colors": {}}}
            """
        let back = try LookStore.importLook(data: Data(file.utf8))
        #expect(back.author == "Anna")
        #expect(back.basedOn?.id == "night")
        #expect(back.style["kiwishelf.thickness"] == .number(30))
    }

    @Test("a credit survives the library round trip")
    func libraryKeepsTheCredit() throws {
        var credited = look()
        credited.author = "Anna"
        let data = try JSONEncoder().encode(
            LookDocument(looks: [credited])
        )
        let back = try JSONDecoder().decode(LookDocument.self, from: data)
        #expect(back.looks.first?.author == "Anna")
        #expect(back.looks.first?.admitted.author == "Anna")
    }

    @Test("a file without a format crosses the look-path steps")
    func olderFileCrosses() throws {
        let file = """
            {"look": {"name": "Old",
                      "style": {"animations.on_shelf": false},
                      "colors": {}}}
            """
        let back = try LookStore.importLook(data: Data(file.utf8))
        #expect(back.style["animations.on_expand"] == .bool(false))
        #expect(back.style["animations.on_shelf"] == nil)
    }

    @Test("a newer file is refused with its format")
    func newerFileRefuses() {
        let newer = LookDocument.currentFormat + 1
        let file = """
            {"format": \(newer),
             "look": {"name": "New", "style": {}, "colors": {}}}
            """
        #expect(throws: LookStore.StoreError.newerLookFile(newer)) {
            try LookStore.importLook(data: Data(file.utf8))
        }
    }

    @Test("a newer file is refused even when its body changed shape")
    func newerShapeRefuses() {
        let newer = LookDocument.currentFormat + 1
        let file = #"{"format": \#(newer), "look": ["reshaped"]}"#
        #expect(throws: LookStore.StoreError.newerLookFile(newer)) {
            try LookStore.importLook(data: Data(file.utf8))
        }
    }

    @Test("an older build's bare export still imports")
    func bareExportImports() throws {
        let data = try JSONEncoder().encode(["look": look()])
        let back = try LookStore.importLook(data: data)
        #expect(back.name == "Dusk")
        #expect(back.author == nil)
    }
}
