import Foundation

/// The look library's Core doors (#1684). A look owns its colours
/// (#1752), so the libraries no longer reach into each other; a
/// write still goes through here, never a store call at a GUI
/// site, and refuses while either library is unreadable — the
/// look library's carry reads the palettes.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`, and public for the same one-owner reason.
    public var lookLibrary: LookStore {
        LookStore(directory: configDirectory)
    }

    /// The bundled looks, Glass derived for the screens the
    /// starter is sized from (`starterSizes`), so picking it on a
    /// first run changes nothing (#1739) — the one door to
    /// `LookCatalog.bundled` (`LookCatalogSeamTests`).
    public var bundledLooks: [ShelfLook] {
        LookCatalog.bundled(sizes: starterSizes())
    }

    /// Every palette a look may name, bundled first.
    public var allPalettes: [ColorPalette] {
        paletteLibrary.builtins() + paletteLibrary.userPalettes()
    }

    /// Renames a user palette; refuses while a library is
    /// unreadable.
    public func renamePalette(from old: String, to new: String) throws {
        try requireReadableLibraries()
        try paletteLibrary.rename(from: old, to: new)
    }

    /// A saved palette that reproduces `settings`' colours, if any.
    public func palette(reproducing settings: TilingSettings)
        -> ColorPalette?
    {
        Self.palette(reproducing: settings, in: allPalettes)
    }

    /// The first of `palettes` reproducing `settings`' colours — the
    /// pure half, which the Settings window hands its in-memory
    /// copy of the library (#805) rather than reading the file.
    public static func palette(
        reproducing settings: TilingSettings,
        in palettes: [ColorPalette]
    ) -> ColorPalette? {
        let live = ColorPaletteKeys.extract(from: settings)
        return palettes.first { $0.reproduces(live) }
    }

    /// Saves `settings`' styling and colours as look `name`.
    /// Refuses while either library is unreadable.
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        try requireReadableLibraries()
        let look = ShelfLook(
            name: name,
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        try lookLibrary.save(look)
        return look
    }

    /// Imports a look file under a free name — one from before
    /// #1752 carried against the palette it travelled with, then
    /// the palettes saved here.
    @discardableResult
    public func importLook(
        from url: URL,
        fallbackName: String
    ) throws -> ShelfLook {
        try requireReadableLibraries()
        var look = try lookLibrary.importLook(
            from: url,
            palettes: allPalettes
        )
        let looks = lookLibrary
        look.name = Self.uniqueName(
            base: Self.named(look.name, else: fallbackName)
        ) { looks.isBuiltinName($0) || looks.hasUserLook($0) }
        try lookLibrary.save(look)
        return look
    }

    /// Throws while either library exists but will not decode — a
    /// write across both must not land half, nor read an
    /// unreadable library's names as free.
    private func requireReadableLibraries() throws {
        _ = try lookLibrary.libraryLooks()
        _ = try paletteLibrary.libraryPalettes()
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
