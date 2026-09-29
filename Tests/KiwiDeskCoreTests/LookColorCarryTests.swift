import Foundation
import Testing

@testable import KiwiDeskCore

/// `looks.json` below format 2 takes each look's colours out of the
/// palette it named (#1752), on the store's first read — a byte
/// step cannot, since the palettes are another file. Fixtures come
/// from the encoder of the old shape (`PaletteNamedLook`).
@Suite("Look colour carry")
struct LookColorCarryTests {
    private let mine = ColorPalette(
        name: "Mine",
        colors: ["kiwishelf.fill_color": "#123456"]
    )

    private func directory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("carry-\(UUID().uuidString)")
    }

    /// A format-1 library as #1684's build wrote it.
    private func writeLegacy(
        _ looks: [PaletteNamedLook],
        in directory: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(LegacyDocument(looks: looks)).write(
            to: directory.appendingPathComponent("looks.json")
        )
    }

    private func named(_ palette: String?) -> PaletteNamedLook {
        PaletteNamedLook(
            name: "A",
            palette: palette,
            style: ["kiwishelf.thickness": .number(30)]
        )
    }

    @Test("a look takes its user palette's colours, whole")
    func userPalette() throws {
        let dir = directory()
        try PaletteStore(directory: dir).save(mine)
        try writeLegacy([named("Mine")], in: dir)
        let looks = try LookStore(directory: dir).libraryLooks()
        #expect(looks.map(\.colors) == [mine.paintedColors])
        #expect(looks.first?.style == named("Mine").style)
    }

    @Test("a look takes its bundled palette's colours")
    func bundledPalette() throws {
        let dir = directory()
        let slate = try #require(
            PaletteCatalog.bundled().first { $0.name == "Slate" }
        )
        try writeLegacy([named("Slate")], in: dir)
        let looks = try LookStore(directory: dir).libraryLooks()
        #expect(looks.map(\.colors) == [slate.paintedColors])
    }

    @Test("a gone or unnamed palette gives the shipped colours")
    func gonePalette() throws {
        let dir = directory()
        try writeLegacy([named("Gone"), named(nil)], in: dir)
        let looks = try LookStore(directory: dir).libraryLooks()
        let shipped = PaletteCatalog.defaultPalette().paintedColors
        #expect(looks.map(\.colors) == [shipped, shipped])
    }

    @Test("the carry is written once, at the current format")
    func carryEnds() throws {
        let dir = directory()
        try PaletteStore(directory: dir).save(mine)
        try writeLegacy([named("Mine")], in: dir)
        let store = LookStore(directory: dir)
        _ = try store.libraryLooks()
        let data = try Data(contentsOf: store.url)
        #expect(!LookColorCarry.isOwed(data))
        // A later rename cannot reach the carried look.
        try PaletteStore(directory: dir).delete("Mine")
        #expect(store.userLooks().map(\.colors) == [mine.paintedColors])
    }

    @Test("an unreadable palette library stands the carry down")
    func unreadablePalettes() throws {
        let dir = directory()
        try writeLegacy([named("Mine")], in: dir)
        try Data(#"{"format": 99, "palettes": []}"#.utf8).write(
            to: dir.appendingPathComponent("palettes.json")
        )
        let store = LookStore(directory: dir)
        let before = try Data(contentsOf: store.url)
        #expect(throws: LookStore.StoreError.unreadableLibrary) {
            try store.libraryLooks()
        }
        #expect(try Data(contentsOf: store.url) == before)
    }

    /// A blind format stamp would end the crossing with no colours.
    @Test("a byte step never stamps past the carry")
    func stampStopsBelowTheCarry() throws {
        let legacy = try JSONEncoder().encode(
            LegacyDocument(looks: [named("Mine")], format: 0)
        )
        let stamped = ConfigMigration.migrated(legacy) ?? legacy
        #expect(LookColorCarry.isOwed(stamped))
    }

    private struct LegacyDocument: Encodable {
        let looks: [PaletteNamedLook]
        var format = 1
    }
}
