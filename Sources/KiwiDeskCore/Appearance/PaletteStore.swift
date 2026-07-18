import Foundation

/// The palette library (#375): the seven built-ins plus the user's
/// saved palettes, persisted **globally** (not per-profile) in
/// `<config>/palettes.json`. Built-ins are read-only — they can't
/// be renamed, overwritten, or deleted; user palettes can. Names
/// are values inside the JSON (not file names), so there's no
/// path-traversal surface here.
///
/// Stateless and file-backed: every call reads or writes the file,
/// so a palette saved in one place is seen everywhere without a
/// cache to invalidate.
public final class PaletteStore {
    public enum StoreError: Error, Equatable {
        /// A user palette may not take a built-in's name.
        case reservedName(String)
        /// Rename/delete targeted a name no user palette has.
        case notFound(String)
        /// The imported file wasn't a valid palette.
        case invalidFile
    }

    private let fileURL: URL

    /// `directory` is the config dir (`~/.config/KiwiDesk`); the
    /// library lives in `palettes.json` inside it.
    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("palettes.json")
    }

    // MARK: - Reads

    /// The built-in palettes (default first) — read-only.
    public func builtins() -> [ColorPalette] {
        PaletteCatalog.bundled()
    }

    /// The user's saved palettes, in saved order.
    public func userPalettes() -> [ColorPalette] {
        guard let data = try? Data(contentsOf: fileURL),
            let palettes = try? JSONDecoder().decode(
                [ColorPalette].self,
                from: data
            )
        else { return [] }
        return palettes
    }

    /// True if `name` belongs to a built-in (reserved).
    public func isBuiltinName(_ name: String) -> Bool {
        builtins().contains { $0.name == name }
    }

    /// True if a user palette already has `name`.
    public func hasUserPalette(_ name: String) -> Bool {
        userPalettes().contains { $0.name == name }
    }

    // MARK: - Writes (user palettes only)

    /// Adds `palette`, or overwrites the existing user palette of
    /// the same name (the caller confirms overwrite first). Throws
    /// `reservedName` if the name is a built-in's.
    public func save(_ palette: ColorPalette) throws {
        guard !isBuiltinName(palette.name) else {
            throw StoreError.reservedName(palette.name)
        }
        var palettes = userPalettes()
        if let index = palettes.firstIndex(where: {
            $0.name == palette.name
        }) {
            palettes[index] = palette
        } else {
            palettes.append(palette)
        }
        try write(palettes)
    }

    /// Deletes the user palette named `name`.
    public func delete(_ name: String) throws {
        var palettes = userPalettes()
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

    /// Renames a user palette. Throws `notFound` if `from` isn't a
    /// user palette, `reservedName` if `to` is a built-in's name.
    public func rename(from: String, to: String) throws {
        guard !isBuiltinName(to) else {
            throw StoreError.reservedName(to)
        }
        var palettes = userPalettes()
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

    // MARK: - Export / import

    /// Writes one palette to `url` (a Finder Save panel location).
    public func export(_ palette: ColorPalette, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        try encoder.encode(palette).write(to: url)
    }

    /// Reads one palette from `url` (a Finder Open panel location).
    /// Filters the colors to known paths so an alien file can't
    /// smuggle junk keys into the library.
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
        try encoder.encode(palettes).write(to: fileURL)
    }
}
