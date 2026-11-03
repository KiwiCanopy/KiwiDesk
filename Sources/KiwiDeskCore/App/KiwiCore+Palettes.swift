import Foundation

/// The palette library's Core doors (#2875), beside the look
/// library's (#2860): the GUI reads and writes palettes through
/// here and never holds the store (`PaletteDoorSeamTests`), and
/// the store refuses a write while its own file is unreadable.
extension KiwiCore {
    /// The bundled palettes.
    public var bundledPalettes: [ColorPalette] {
        paletteLibrary.builtins()
    }

    /// The saved user palettes, read from disk.
    public var userPalettes: [ColorPalette] {
        paletteLibrary.userPalettes()
    }

    /// Every palette, bundled first.
    public var allPalettes: [ColorPalette] {
        bundledPalettes + userPalettes
    }

    /// `base`, trimmed, or the first `base N` no bundled or user
    /// palette holds.
    public func freePaletteName(base: String) -> String {
        let library = paletteLibrary
        return Self.uniqueName(base: LibraryNameVerdict.normalized(base)) {
            library.isBuiltinName($0) || library.hasUserPalette($0)
        }
    }

    /// Saves `settings`' colours as palette `name`; a name
    /// `paletteNameVerdict` refuses throws `LibraryNameRefusal`.
    @discardableResult
    public func savePalette(
        named name: String,
        from settings: TilingSettings
    ) throws -> ColorPalette {
        let palette = ColorPalette(
            name: try admittedName(name, paletteNameVerdict(name)),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        try paletteLibrary.save(palette)
        return palette
    }

    /// Renames a user palette; no look names one (#1752).
    public func renamePalette(from old: String, to new: String) throws {
        let name = try admittedName(
            new,
            paletteNameVerdict(new, renaming: old)
        )
        try paletteLibrary.rename(from: old, to: name)
    }

    /// Deletes a user palette.
    public func deletePalette(_ name: String) throws {
        try paletteLibrary.delete(name)
    }

    /// Writes `palette` as a bare palette file at `url`.
    public func exportPalette(
        _ palette: ColorPalette,
        to url: URL
    ) throws {
        try paletteLibrary.export(palette, to: url)
    }

    /// Imports a palette file under the next free name, so it never
    /// shadows a bundled or an existing user palette.
    @discardableResult
    public func importPalette(from url: URL) throws -> ColorPalette {
        let imported = try paletteLibrary.importPalette(from: url)
        let palette = ColorPalette(
            name: freePaletteName(base: imported.name),
            colors: imported.colors
        )
        try paletteLibrary.save(palette)
        return palette
    }
}
