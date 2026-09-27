import Foundation

/// The look library's Core doors (#1684). A look names a palette,
/// so every write that touches both libraries goes through here —
/// never two store calls at a GUI site — keeping one colour library:
/// a palette rename carries its looks, and a look's colours land in
/// a palette without ever overwriting one of the user's.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`, and public for the same one-owner reason.
    public var lookLibrary: LookStore {
        LookStore(directory: configDirectory)
    }

    /// Every palette a look may name, bundled first.
    public var allPalettes: [ColorPalette] {
        paletteLibrary.builtins() + paletteLibrary.userPalettes()
    }

    /// Renames a user palette and re-points the looks naming it;
    /// refuses before either write while a library is unreadable.
    public func renamePalette(from old: String, to new: String) throws {
        try requireReadableLibraries()
        try paletteLibrary.rename(from: old, to: new)
        try lookLibrary.repointPalette(from: old, to: new)
    }

    /// A saved palette that reproduces `settings`' colours, if any.
    public func palette(reproducing settings: TilingSettings)
        -> ColorPalette?
    {
        let live = ColorPaletteKeys.extract(from: settings)
        return allPalettes.first { $0.reproduces(live) }
    }

    /// The palette name a new look `name` would file its colours
    /// under: `name`, else the next free `name N`.
    public func newPaletteName(for name: String) -> String {
        let palettes = paletteLibrary
        return Self.uniqueName(base: name) {
            palettes.isBuiltinName($0) || palettes.hasUserPalette($0)
        }
    }

    /// Saves `settings`' styling as look `name`, naming the palette
    /// that reproduces its colours or filing them as a new one.
    /// Refuses before writing anything while either library is
    /// unreadable, so no orphan palette is left behind.
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        try requireReadableLibraries()
        let paletteName: String
        if let matching = palette(reproducing: settings) {
            paletteName = matching.name
        } else {
            paletteName = newPaletteName(for: name)
            try paletteLibrary.save(
                ColorPalette(
                    name: paletteName,
                    colors: ColorPaletteKeys.extract(from: settings)
                )
            )
        }
        let look = ShelfLook(
            name: name,
            palette: paletteName,
            style: LookKeys.extract(from: settings)
        )
        try lookLibrary.save(look)
        return look
    }

    /// Imports a look file under a free name; the palette it
    /// carries is reused where one with the same colours is saved,
    /// else filed under a free name, and the look re-pointed at it.
    @discardableResult
    public func importLook(
        from url: URL,
        fallbackName: String
    ) throws -> ShelfLook {
        try requireReadableLibraries()
        let file = try lookLibrary.importLook(from: url)
        var look = file.look
        let looks = lookLibrary
        look.name = Self.uniqueName(
            base: Self.named(look.name, else: fallbackName)
        ) { looks.isBuiltinName($0) || looks.hasUserLook($0) }
        if let palette = file.palette {
            look.palette = try fileImported(
                palette,
                fallbackName: look.name
            )
        }
        try lookLibrary.save(look)
        return look
    }

    private func fileImported(
        _ palette: ColorPalette,
        fallbackName: String
    ) throws -> String {
        let painted = Self.painted(palette)
        if let same = allPalettes.first(where: { $0.reproduces(painted) }) {
            return same.name
        }
        let free = newPaletteName(
            for: Self.named(palette.name, else: fallbackName)
        )
        try paletteLibrary.save(
            ColorPalette(name: free, colors: palette.colors)
        )
        return free
    }

    /// Throws while either library exists but will not decode — a
    /// write across both must not land half, nor read an
    /// unreadable library's names as free.
    private func requireReadableLibraries() throws {
        _ = try lookLibrary.libraryLooks()
        _ = try paletteLibrary.libraryPalettes()
    }

    /// The colour map `palette` gives over the shipped colours.
    private static func painted(
        _ palette: ColorPalette
    ) -> [String: String] {
        var base = TilingSettings()
        palette.apply(to: &base)
        return ColorPaletteKeys.extract(from: base)
    }

    /// `name` trimmed, or `fallback` when nothing is left.
    static func named(_ name: String, else fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// `base`, then `base 2`, `base 3`, … skipping taken names.
    public static func uniqueName(
        base: String,
        taken: (String) -> Bool
    ) -> String {
        guard taken(base) else { return base }
        var n = 2
        while taken("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    /// Writes a bundle's looks, returning how many were refused.
    /// A bundle from before looks travelled carries none and
    /// leaves the library alone (`SetupBundle.replaces`).
    func writeIncomingLooks(
        _ bundle: SetupBundle
    ) throws(SetupBundleError) -> Int {
        guard let looks = bundle.looks, !looks.isEmpty else {
            return 0
        }
        do {
            return try lookLibrary.replaceUserLooks(with: looks)
        } catch {
            onLog("restore: looks write failed: \(error)")
            throw .couldNotWrite(name: lookLibrary.url.lastPathComponent)
        }
    }
}
