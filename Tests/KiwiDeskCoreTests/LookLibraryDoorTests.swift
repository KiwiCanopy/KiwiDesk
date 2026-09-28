import Foundation
import Testing

@testable import KiwiDeskCore

/// Core's one door over both libraries (#1684): a look's colours
/// land in a palette without overwriting one, a palette rename
/// carries its looks, and an import files names it may not shadow.
@Suite("Look library door")
@MainActor
struct LookLibraryDoorTests {
    @Test("saving reuses a palette that reproduces the colours")
    func saveReusesPalette() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        let slate = try #require(
            PaletteCatalog.bundled().first { $0.name == "Slate" }
        )
        slate.apply(to: &settings)
        let look = try core.saveLook(named: "Mine", from: settings)
        #expect(look.palette == "Slate")
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }

    @Test("a sparse palette whose few keys agree is not reused")
    func sparseMatchIsNotEnough() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        try core.paletteLibrary.save(
            ColorPalette(
                name: "Sparse",
                colors: [
                    "border.focused_color":
                        TilingSettings().borderStyle.focusedColor
                ]
            )
        )
        let look = try core.saveLook(named: "Mine", from: settings)
        #expect(look.palette == "Mine")
        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["Sparse", "Mine"]
        )
    }

    @Test("new colours never overwrite a user palette")
    func neverOverwrites() throws {
        let core = makeTestCore()
        let theirs = ColorPalette(
            name: "Mine",
            colors: ["kiwishelf.fill_color": "#FFFFFF"]
        )
        try core.paletteLibrary.save(theirs)
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        let look = try core.saveLook(named: "Mine", from: settings)
        #expect(look.palette == "Mine 2")
        #expect(core.paletteLibrary.userPalettes().first == theirs)
    }

    @Test("a palette rename carries the looks drawn in it")
    func renameRepoints() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        try core.saveLook(named: "Mine", from: settings)
        try core.renamePalette(from: "Mine", to: "Ours")
        #expect(core.lookLibrary.userLooks().first?.palette == "Ours")
    }

    @Test("a failed rename re-points nothing")
    func failedRenameKeepsPointer() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        try core.saveLook(named: "Mine", from: settings)
        #expect(throws: (any Error).self) {
            try core.renamePalette(from: "Mine", to: "Slate")
        }
        #expect(core.lookLibrary.userLooks().first?.palette == "Mine")
    }

    @Test("an import trims names and never shadows")
    func importNames() throws {
        let core = makeTestCore()
        try core.lookLibrary.save(
            ShelfLook(name: "Mine", palette: nil, style: [:])
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
        try core.lookLibrary.export(
            LookExport(
                look: ShelfLook(name: "  Mine ", palette: "P", style: [:]),
                palette: ColorPalette(
                    name: " ",
                    colors: ["kiwishelf.fill_color": "#123456"]
                )
            ),
            to: url
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        #expect(look.name == "Mine 2")
        #expect(look.palette == "Mine 2")
        #expect(core.paletteLibrary.hasUserPalette("Mine 2"))
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
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        #expect(throws: (any Error).self) {
            try core.saveLook(named: "Mine", from: settings)
        }
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }

    @Test("an unreadable palette library refuses an import")
    func importRefusesUnreadablePalettes() throws {
        let core = makeTestCore()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
        try core.lookLibrary.export(
            LookExport(
                look: ShelfLook(name: "A", palette: "P", style: [:]),
                palette: ColorPalette(
                    name: "P",
                    colors: ["kiwishelf.fill_color": "#123456"]
                )
            ),
            to: url
        )
        try poison(core.paletteLibrary.url, key: "palettes")
        #expect(throws: (any Error).self) {
            try core.importLook(from: url, fallbackName: "My Look")
        }
        #expect(core.lookLibrary.userLooks().isEmpty)
    }

    @Test("an import reuses a saved palette with the same colours")
    func importReusesPalette() throws {
        let core = makeTestCore()
        let slate = try #require(
            PaletteCatalog.bundled().first { $0.name == "Slate" }
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
        try core.lookLibrary.export(
            LookExport(
                look: ShelfLook(name: "A", palette: "Theirs", style: [:]),
                palette: ColorPalette(name: "Theirs", colors: slate.colors)
            ),
            to: url
        )
        let look = try core.importLook(from: url, fallbackName: "My Look")
        #expect(look.palette == "Slate")
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }
}
