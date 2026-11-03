import Foundation
import Testing

@testable import KiwiDeskCore

/// One Core verdict on a typed palette or look name (#2953): the
/// button reads it and the write refuses through it, so the two
/// never disagree.
@Suite("Library name verdict")
@MainActor
struct LibraryNameVerdictTests {
    private func bundledLook(_ core: KiwiCore) throws -> String {
        try #require(core.bundledLooks.first).name
    }

    @Test("a save is free, overwrites, blank or bundled")
    func saveVerdicts() throws {
        let core = makeTestCore()
        let palette = try #require(core.bundledPalettes.first).name
        _ = try core.savePalette(named: "Mine", from: TilingSettings())
        #expect(core.paletteNameVerdict("Free") == .free)
        #expect(core.paletteNameVerdict(" Mine ") == .overwrites)
        #expect(core.paletteNameVerdict("Mine").isAllowed)
        #expect(core.paletteNameVerdict("  ") == .blank)
        #expect(core.paletteNameVerdict(palette) == .bundled)
        let look = try bundledLook(core)
        _ = try core.saveLook(named: "Mine", from: TilingSettings())
        #expect(core.lookNameVerdict("Free") == .free)
        #expect(core.lookNameVerdict("Mine") == .overwrites)
        #expect(core.lookNameVerdict("Mine").isAllowed)
        #expect(core.lookNameVerdict("") == .blank)
        #expect(core.lookNameVerdict(look) == .bundled)
    }

    @Test("a rename keeps its own name and refuses another's")
    func renameVerdicts() throws {
        let core = makeTestCore()
        _ = try core.saveLook(named: "Mine", from: TilingSettings())
        _ = try core.saveLook(named: "Ours", from: TilingSettings())
        #expect(core.lookNameVerdict("Mine", renaming: "Mine") == .free)
        #expect(core.lookNameVerdict("Ours", renaming: "Mine") == .taken)
        #expect(core.lookNameVerdict("New", renaming: "Mine") == .free)
        _ = try core.savePalette(named: "Mine", from: TilingSettings())
        _ = try core.savePalette(named: "Ours", from: TilingSettings())
        #expect(
            core.paletteNameVerdict("Ours", renaming: "Mine") == .taken
        )
    }

    /// The write doors refuse exactly what the verdict refuses.
    @Test("a write lands where the verdict allows it, only there")
    func writesFollowTheVerdict() throws {
        let core = makeTestCore()
        let palette = try #require(core.bundledPalettes.first).name
        let look = try bundledLook(core)
        let settings = TilingSettings()
        for name in ["Mine", "Mine", " ", palette] {
            let verdict = core.paletteNameVerdict(name)
            let saved = (try? core.savePalette(named: name, from: settings))
            #expect((saved != nil) == verdict.isAllowed, "\(name)")
        }
        #expect(throws: LibraryNameRefusal(verdict: .bundled)) {
            try core.saveLook(named: look, from: settings)
        }
        #expect(throws: LibraryNameRefusal(verdict: .blank)) {
            try core.saveLook(named: "", from: settings)
        }
        _ = try core.saveLook(named: "Mine", from: settings)
        _ = try core.saveLook(named: "Ours", from: settings)
        #expect(throws: LibraryNameRefusal(verdict: .taken)) {
            try core.renameLook(from: "Mine", to: "Ours")
        }
        _ = try core.savePalette(named: "Ours", from: settings)
        #expect(throws: LibraryNameRefusal(verdict: .taken)) {
            try core.renamePalette(from: "Mine", to: "Ours")
        }
        try core.renameLook(from: "Mine", to: "Mine")
        try core.renamePalette(from: "Mine", to: "Mine")
        #expect(throws: LibraryNameRefusal(verdict: .blank)) {
            try core.renameLook(from: "Mine", to: " ")
        }
        try core.renameLook(from: "Mine", to: "New")
        #expect(core.userLooks.map(\.name).sorted() == ["New", "Ours"])
    }

    /// A door judges and stores one trimmed name, so a padded name
    /// lands on the entry the verdict named.
    @Test("a padded name is judged and stored trimmed")
    func paddedNamesAreTrimmed() throws {
        let core = makeTestCore()
        let settings = TilingSettings()
        _ = try core.savePalette(named: "Mine", from: settings)
        _ = try core.savePalette(named: " Mine ", from: settings)
        #expect(core.userPalettes.map(\.name) == ["Mine"])
        _ = try core.saveLook(named: " Mine ", from: settings)
        try core.renameLook(from: "Mine", to: " New ")
        #expect(core.userLooks.map(\.name) == ["New"])
        #expect(core.freeLookName(base: " New ") == "New 2")
        #expect(core.freePaletteName(base: " Mine ") == "Mine 2")
    }
}
