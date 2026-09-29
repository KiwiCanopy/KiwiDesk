import Foundation
import Testing

@testable import KiwiDeskCore

/// Core's one door over the look library (#1684): a look owns its
/// colours (#1752), so a save files no palette and a palette rename
/// reaches no look, while an import names what it may not shadow
/// and carries an old file's colours in.
@Suite("Look library door")
@MainActor
struct LookLibraryDoorTests {
    @Test("saving keeps the colours whole and files no palette")
    func saveOwnsColours() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        let look = try core.saveLook(named: "Mine", from: settings)
        #expect(look.colors == ColorPaletteKeys.extract(from: settings))
        #expect(core.paletteLibrary.userPalettes().isEmpty)
        #expect(core.lookLibrary.userLooks() == [look])
    }

    @Test("a palette rename reaches no look")
    func renameLeavesLooks() throws {
        let core = makeTestCore()
        try core.paletteLibrary.save(
            ColorPalette(
                name: "Mine",
                colors: ["kiwishelf.fill_color": "#123456"]
            )
        )
        let settings = TilingSettings()
        let look = try core.saveLook(named: "Look", from: settings)
        try core.renamePalette(from: "Mine", to: "Ours")
        #expect(core.lookLibrary.userLooks() == [look])
        #expect(core.paletteLibrary.hasUserPalette("Ours"))
    }

    @Test("an import trims names and never shadows")
    func importNames() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(
            ShelfLook(name: "Mine", style: [:], colors: [:])
        )
        let url = try exported(
            ShelfLook(
                name: "  Mine ",
                style: [:],
                colors: ["kiwishelf.fill_color": "#123456"]
            )
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        #expect(look.name == "Mine 2")
        #expect(look.colors == ["kiwishelf.fill_color": "#123456"])
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }

    @Test("an old file takes the colours of the palette it carried")
    func legacyImportCarriesTravelledPalette() throws {
        let core = makeTestCore()
        let theirs = ColorPalette(
            name: "Slate",
            colors: ["kiwishelf.fill_color": "#123456"]
        )
        let url = try legacyExported(
            PaletteNamedLook(name: "A", palette: "Slate", style: [:]),
            palette: theirs
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        // The file's own palette outranks a bundled one of that name.
        #expect(look.colors == theirs.paintedColors)
    }

    @Test("an old file naming a bundled palette takes its colours")
    func legacyImportResolvesBundled() throws {
        let core = makeTestCore()
        let slate = try #require(
            PaletteCatalog.bundled().first { $0.name == "Slate" }
        )
        let url = try legacyExported(
            PaletteNamedLook(name: "A", palette: "Slate", style: [:]),
            palette: nil
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        #expect(look.colors == slate.paintedColors)
    }

    @Test("an old file naming no known palette takes the shipped colours")
    func legacyImportFallsBack() throws {
        let core = makeTestCore()
        let url = try legacyExported(
            PaletteNamedLook(name: "A", palette: "Gone", style: [:]),
            palette: nil
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        #expect(
            look.colors == PaletteCatalog.defaultPalette().paintedColors
        )
    }

    /// Writes a library file this build refuses (a newer format).
    private func poison(_ url: URL, key: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(#"{"format": 99, "\#(key)": []}"#.utf8).write(to: url)
    }

    @Test("an unreadable look library refuses before any write")
    func saveRefusesUnreadableLooks() throws {
        let core = makeTestCore()
        try poison(core.lookLibrary.url, key: "looks")
        #expect(throws: (any Error).self) {
            try core.saveLook(named: "Mine", from: TilingSettings())
        }
    }

    @Test("an unreadable palette library refuses an import")
    func importRefusesUnreadablePalettes() throws {
        let core = makeTestCore()
        let url = try exported(
            ShelfLook(name: "A", style: [:], colors: [:])
        )
        try poison(core.paletteLibrary.url, key: "palettes")
        #expect(throws: (any Error).self) {
            try core.importLook(from: url, fallbackName: "My Look")
        }
        #expect(core.lookLibrary.userLooks().isEmpty)
    }

    private func exported(_ look: ShelfLook) throws -> URL {
        let url = scratchFile()
        try LookStore(directory: url.deletingLastPathComponent())
            .export(LookExport(look: look), to: url)
        return url
    }

    /// A look file as a build before #1752 wrote it, by its encoder.
    private func legacyExported(
        _ look: PaletteNamedLook,
        palette: ColorPalette?
    ) throws -> URL {
        let url = scratchFile()
        try JSONEncoder().encode(
            LegacyExport(look: look, palette: palette)
        ).write(to: url)
        return url
    }

    private func scratchFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
    }

    private struct LegacyExport: Encodable {
        let look: PaletteNamedLook
        let palette: ColorPalette?
    }
}
