import Foundation
import Testing

@testable import KiwiDeskCore

/// Core's one door over the look library (#1684): a look owns its
/// colours (#1752), so a save files no palette and a palette rename
/// reaches no look, while an import names what it may not shadow.
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
        #expect(look.colors["kiwishelf.fill_color"] == "#123456")
        #expect(core.paletteLibrary.userPalettes().isEmpty)
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

    private func exported(_ look: ShelfLook) throws -> URL {
        let url = scratchFile()
        try LookStore(directory: url.deletingLastPathComponent())
            .export(LookExport(look: look), to: url)
        return url
    }

    private func scratchFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("look-\(UUID().uuidString).json")
    }
}
