import Foundation

/// The palette library's Core doors (#2875), beside the look
/// library's (#2860): a write goes through here, never a store
/// call at a GUI site, and the store refuses while its own file
/// is unreadable.
extension KiwiCore {
    /// Every palette, bundled first.
    public var allPalettes: [ColorPalette] {
        paletteLibrary.builtins() + paletteLibrary.userPalettes()
    }

    /// Saves `settings`' colours as palette `name`.
    @discardableResult
    public func savePalette(
        named name: String,
        from settings: TilingSettings
    ) throws -> ColorPalette {
        let palette = ColorPalette(
            name: name,
            colors: ColorPaletteKeys.extract(from: settings)
        )
        try paletteLibrary.save(palette)
        return palette
    }

    /// Renames a user palette; no look names one (#1752).
    public func renamePalette(from old: String, to new: String) throws {
        try paletteLibrary.rename(from: old, to: new)
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
        let library = paletteLibrary
        let imported = try library.importPalette(from: url)
        let palette = ColorPalette(
            name: Self.uniqueName(base: imported.name) {
                library.isBuiltinName($0) || library.hasUserPalette($0)
            },
            colors: imported.colors
        )
        try library.save(palette)
        return palette
    }
}
