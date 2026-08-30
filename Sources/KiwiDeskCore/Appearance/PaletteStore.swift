import Foundation

/// Global palette library store managing `palettes.json` (#375, #945, #606).
public final class PaletteStore {
    public enum StoreError: Error, Equatable {
        case reservedName(String)
        case notFound(String)
        case duplicateName(String)
        case invalidFile
        /// Unreadable or newer-format library (#945 review).
        case unreadableLibrary
    }

    private let fileURL: URL

    /// URL to `palettes.json` (#606).
    public var url: URL { fileURL }

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("palettes.json")
    }

    /// Read-only built-in palettes.
    public func builtins() -> [ColorPalette] {
        PaletteCatalog.bundled()
    }

    /// Decodes document, running `ConfigMigration` if needed (#945).
    private func readDocument() throws -> PaletteDocument? {
        guard var data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        if let migrated = ConfigMigration.migrated(data) {
            data = migrated
            try? migrated.write(to: fileURL, options: .atomic)
        }
        guard
            let doc = try? JSONDecoder().decode(
                PaletteDocument.self,
                from: data
            )
        else { throw StoreError.unreadableLibrary }
        return doc
    }

    /// User palettes for mutating paths (throws on unreadable library, #945).
    public func libraryPalettes() throws -> [ColorPalette] {
        try readDocument()?.palettes ?? []
    }

    /// User palettes for read queries (defaults to empty on error).
    public func userPalettes() -> [ColorPalette] {
        (try? libraryPalettes()) ?? []
    }

    public func isBuiltinName(_ name: String) -> Bool {
        builtins().contains { $0.name == name }
    }

    public func hasUserPalette(_ name: String) -> Bool {
        userPalettes().contains { $0.name == name }
    }

    /// Saves or updates a user palette.
    public func save(_ palette: ColorPalette) throws {
        guard !isBuiltinName(palette.name) else {
            throw StoreError.reservedName(palette.name)
        }
        var palettes = try libraryPalettes()
        if let index = palettes.firstIndex(where: {
            $0.name == palette.name
        }) {
            palettes[index] = palette
        } else {
            palettes.append(palette)
        }
        try write(palettes)
    }

    /// Bulk replaces user palettes during backup restore (#606).
    @discardableResult
    public func replaceUserPalettes(
        with palettes: [ColorPalette]
    ) throws -> Int {
        let known = Set(ColorPaletteKeys.all)
        var seen: Set<String> = []
        var admissible: [ColorPalette] = []
        for palette in palettes {
            guard !isBuiltinName(palette.name),
                seen.insert(palette.name).inserted
            else { continue }
            admissible.append(
                ColorPalette(
                    name: palette.name,
                    colors: palette.colors.filter {
                        known.contains($0.key)
                    }
                )
            )
        }
        try write(admissible)
        return palettes.count - admissible.count
    }

    public func delete(_ name: String) throws {
        var palettes = try libraryPalettes()
        guard
            let index = palettes.firstIndex(where: {
                $0.name == name
            })
        else {
            throw StoreError.notFound(name)
        }
        palettes.remove(at: index)
        try write(palettes)
    }

    public func rename(from: String, to: String) throws {
        guard !isBuiltinName(to) else {
            throw StoreError.reservedName(to)
        }
        guard to == from || !hasUserPalette(to) else {
            throw StoreError.duplicateName(to)
        }
        var palettes = try libraryPalettes()
        guard
            let index = palettes.firstIndex(where: {
                $0.name == from
            })
        else {
            throw StoreError.notFound(from)
        }
        palettes[index].name = to
        try write(palettes)
    }

    public func export(_ palette: ColorPalette, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        try encoder.encode(palette).write(to: url)
    }

    /// Imports palette from file URL (#945 review).
    public func importPalette(from url: URL) throws -> ColorPalette {
        guard let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode(
                ColorPalette.self,
                from: data
            )
        else {
            throw StoreError.invalidFile
        }
        let known = Set(ColorPaletteKeys.all)
        let colors = raw.colors.filter { known.contains($0.key) }
        return ColorPalette(name: raw.name, colors: colors)
    }

    private func write(_ palettes: [ColorPalette]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        let doc = PaletteDocument(
            format: PaletteDocument.currentFormat,
            palettes: palettes
        )
        try encoder.encode(doc).write(
            to: fileURL,
            options: .atomic
        )
    }
}
