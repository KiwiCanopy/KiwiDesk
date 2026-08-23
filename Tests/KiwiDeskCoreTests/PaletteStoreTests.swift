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
        colors: ["app_bar.fill_color": "#112233"]
    )

    @Test("Built-ins are the catalog; no user palettes at first")
    func initialState() {
        let (store, _) = makeStore()
        #expect(store.builtins().count == 9)
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
                "app_bar.fill_color": "#010203",
                "totally.made.up": "#FFFFFF",
            ]
        )
        try JSONEncoder().encode(alien).write(to: url)
        let cleaned = try store.importPalette(from: url)
        #expect(cleaned.colors == ["app_bar.fill_color": "#010203"])
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

    /// Legacy bare-array palettes.json loads, is rewritten wrapped,
    /// and loads with needsMigration == false (#939).
    @Test("Legacy bare-array file migrates and rewrites wrapped")
    func legacyPalettesFileMigrates() throws {
        let (store, dir) = makeStore()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let legacy =
            """
            [{"colors":{"app_bar.fill_color":"#112233"},"name":"Mine"}]
            """
        try Data(legacy.utf8).write(to: store.url)
        let initial = try Data(contentsOf: store.url)
        #expect(ConfigMigration.needsMigration(initial))
        let loaded = store.userPalettes()
        #expect(loaded == [sample])

        let onDisk = try Data(contentsOf: store.url)
        #expect(!ConfigMigration.needsMigration(onDisk))
        let doc = try JSONDecoder().decode(
            PaletteDocument.self,
            from: onDisk
        )
        #expect(doc.format == PaletteDocument.currentFormat)
        #expect(doc.palettes == [sample])
    }

    /// Saved palettes are wrapped and round-trip identically.
    /// The format is asserted on the RAW saved JSON — the
    /// decoder-side read was vacuous (it read the decoder back,
    /// not the file, so a `write` stamping 0 stayed green;
    /// proven by mutation, #945 review).
    @Test("Saved palettes are wrapped and round-trip")
    func savedPalettesAreWrapped() throws {
        let (store, _) = makeStore()
        try store.save(sample)
        let data = try Data(contentsOf: store.url)
        let root =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        #expect(
            root?["format"] as? Int
                == PaletteDocument.currentFormat
        )
        #expect(!ConfigMigration.needsMigration(data))
        let doc = try JSONDecoder().decode(
            PaletteDocument.self,
            from: data
        )
        #expect(doc.palettes == [sample])
        #expect(store.userPalettes() == [sample])
    }

    /// A newer-format library reads as empty for pure QUERIES,
    /// but every read-modify-WRITE path refuses loudly: a
    /// downgraded build's save must not clobber the newer
    /// build's whole library with one palette (#945 review —
    /// the first draft's `[]` was indistinguishable from empty
    /// and enabled exactly that clobber).
    @Test("Newer format is query-empty but refuses mutation")
    func newerPaletteFormatRefusesMutation() throws {
        let (store, dir) = makeStore()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let future = PaletteDocument.currentFormat + 1
        let data =
            """
            {"format":\(future),"palettes":[{"colors":{},"name":"Future"}]}
            """
        try Data(data.utf8).write(to: store.url)
        #expect(store.userPalettes().isEmpty)
        #expect(
            throws: PaletteStore.StoreError.unreadableLibrary
        ) {
            try store.save(self.sample)
        }
        #expect(
            throws: PaletteStore.StoreError.unreadableLibrary
        ) {
            try store.delete("Future")
        }
        // The refusal left the newer library untouched.
        let after = try Data(contentsOf: store.url)
        #expect(after == Data(data.utf8))
    }
}
