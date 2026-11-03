import Foundation
import Testing

@testable import KiwiDeskCore

/// Core's doors over the palette library (#2875), beside the
/// look library's: a save takes the settings' colours, and an
/// import never shadows a bundled or a user palette.
@Suite("Palette library door")
@MainActor
struct PaletteLibraryDoorTests {
    @Test("saving files the settings' colours under the name")
    func saveTakesColours() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        let palette = try core.savePalette(named: "Mine", from: settings)
        #expect(
            palette.colors == ColorPaletteKeys.extract(from: settings)
        )
        #expect(core.paletteLibrary.userPalettes() == [palette])
        #expect(core.lookLibrary.userLooks().isEmpty)
    }

    @Test("a free name skips bundled and user palettes")
    func freeName() throws {
        let core = makeTestCore()
        let builtin = try #require(core.bundledPalettes.first)
        #expect(core.paletteNameVerdict(builtin.name) == .bundled)
        #expect(
            core.freePaletteName(base: builtin.name)
                == "\(builtin.name) 2"
        )
        _ = try core.savePalette(named: "Mine", from: TilingSettings())
        #expect(core.paletteNameVerdict("Mine") == .overwrites)
        #expect(core.freePaletteName(base: "Mine") == "Mine 2")
        #expect(core.freePaletteName(base: "Free") == "Free")
        #expect(core.userPalettes.map(\.name) == ["Mine"])
    }

    @Test("a palette is deleted through the door")
    func delete() throws {
        let core = makeTestCore()
        _ = try core.savePalette(named: "Mine", from: TilingSettings())
        try core.deletePalette("Mine")
        #expect(core.paletteLibrary.userPalettes().isEmpty)
    }

    @Test("an export round-trips through an import under a free name")
    func exportImport() throws {
        let core = makeTestCore()
        var settings = TilingSettings()
        settings.kiwishelf.fillColor = "#123456"
        let saved = try core.savePalette(named: "Mine", from: settings)
        let url =
            testTemporaryDirectory
            .appendingPathComponent("palette-\(UUID().uuidString).json")
        try core.exportPalette(saved, to: url)
        let imported = try core.importPalette(from: url)
        #expect(imported.name == "Mine 2")
        #expect(imported.colors == saved.colors)
        #expect(
            core.paletteLibrary.userPalettes().map(\.name)
                == ["Mine", "Mine 2"]
        )
    }

    @Test("an import never takes a bundled palette's name")
    func importSkipsBuiltins() throws {
        let core = makeTestCore()
        let builtin = try #require(core.paletteLibrary.builtins().first)
        let url =
            testTemporaryDirectory
            .appendingPathComponent("palette-\(UUID().uuidString).json")
        try core.exportPalette(builtin, to: url)
        let imported = try core.importPalette(from: url)
        #expect(imported.name == "\(builtin.name) 2")
        #expect(core.paletteLibrary.hasUserPalette(imported.name))
    }
}
