import Foundation
import Testing

@testable import KiwiDeskCore

/// The palette library persistence (#375): user palettes save,
/// rename, delete, export/import; built-ins stay read-only and
/// their names reserved.
@Suite("Palette store")
struct PaletteStoreTests {
    /// A fresh store over a unique temp dir.
    private func makeStore() -> (PaletteStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("palettes-\(UUID().uuidString)")
        return (PaletteStore(directory: dir), dir)
    }

    private let sample = ColorPalette(
        name: "Mine",
        colors: ["app_bar.box_color": "#112233"]
    )

    @Test("Built-ins are the catalog; no user palettes at first")
    func initialState() {
        let (store, _) = makeStore()
        #expect(store.builtins().count == 7)
        #expect(store.userPalettes().isEmpty)
    }

    @Test("Saving a user palette persists it")
    func saveAndRead() throws {
        let (store, _) = makeStore()
        try store.save(sample)
        #expect(store.userPalettes() == [sample])
        #expect(store.hasUserPalette("Mine"))
    }

    @Test("A built-in name is reserved")
    func reservedName() {
        let (store, _) = makeStore()
        #expect(store.isBuiltinName(PaletteCatalog.defaultName))
        #expect(throws: PaletteStore.StoreError.self) {
            try store.save(
                ColorPalette(
                    name: PaletteCatalog.defaultName,
                    colors: [:]
                )
            )
        }
    }

    @Test("Saving the same name overwrites, not duplicates")
    func overwrite() throws {
        let (store, _) = makeStore()
        try store.save(sample)
        let updated = ColorPalette(
            name: "Mine",
            colors: ["border.focused_color": "#FF0000"]
        )
        try store.save(updated)
        #expect(store.userPalettes() == [updated])
    }

    @Test("Deleting removes a user palette; missing throws")
    func delete() throws {
        let (store, _) = makeStore()
        try store.save(sample)
        try store.delete("Mine")
        #expect(store.userPalettes().isEmpty)
        #expect(throws: PaletteStore.StoreError.self) {
            try store.delete("Nope")
        }
    }

    @Test("Renaming works; to a reserved name throws")
    func rename() throws {
        let (store, _) = makeStore()
        try store.save(sample)
        try store.rename(from: "Mine", to: "Yours")
        #expect(store.hasUserPalette("Yours"))
        #expect(!store.hasUserPalette("Mine"))
        #expect(throws: PaletteStore.StoreError.self) {
            try store.rename(
                from: "Yours",
                to: PaletteCatalog.defaultName
            )
        }
    }

    @Test("Renaming onto another user palette's name throws")
    func renameCollision() throws {
        let (store, _) = makeStore()
        try store.save(sample)  // "Mine"
        try store.save(
            ColorPalette(name: "Other", colors: [:])
        )
        #expect(throws: PaletteStore.StoreError.self) {
            try store.rename(from: "Mine", to: "Other")
        }
        // Both survive — no duplicate, no data loss.
        #expect(store.userPalettes().count == 2)
        // Renaming to its own name is a harmless no-op.
        try store.rename(from: "Mine", to: "Mine")
        #expect(store.hasUserPalette("Mine"))
    }

    @Test("Export then import round-trips a palette")
    func exportImport() throws {
        let (store, dir) = makeStore()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent("out.json")
        try store.export(sample, to: url)
        let back = try store.importPalette(from: url)
        #expect(back == sample)
    }

    @Test("Import drops unknown color keys")
    func importFilters() throws {
        let (store, dir) = makeStore()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent("alien.json")
        let alien = ColorPalette(
            name: "Alien",
            colors: [
                "app_bar.box_color": "#010203",
                "totally.made.up": "#FFFFFF",
            ]
        )
        try JSONEncoder().encode(alien).write(to: url)
        let cleaned = try store.importPalette(from: url)
        #expect(cleaned.colors == ["app_bar.box_color": "#010203"])
    }

    @Test("Importing a non-palette file throws")
    func importInvalid() throws {
        let (store, dir) = makeStore()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent("junk.json")
        try Data("not json".utf8).write(to: url)
        #expect(throws: PaletteStore.StoreError.self) {
            try store.importPalette(from: url)
        }
    }
}
