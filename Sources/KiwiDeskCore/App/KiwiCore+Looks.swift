import Foundation

/// The look library's Core doors (#1684). A look owns its colours
/// (#1752), so the look and palette libraries never reach into
/// each other; a write still goes through here, never a store call
/// at a GUI site, and a store refuses while its own file is
/// unreadable.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`, and public for the same one-owner reason.
    public var lookLibrary: LookStore {
        let store = LookStore(directory: configDirectory)
        store.migrationBackups = migrationBackups
        return store
    }

    /// The bundled looks, Glass derived for the screens the
    /// starter is sized from (`starterSizes`), so picking it on a
    /// first run changes nothing (#1739) — the one door to
    /// `LookCatalog.bundled` (`LookCatalogSeamTests`).
    public var bundledLooks: [ShelfLook] {
        LookCatalog.bundled(sizes: starterSizes())
    }

    /// Every palette, bundled first.
    public var allPalettes: [ColorPalette] {
        paletteLibrary.builtins() + paletteLibrary.userPalettes()
    }

    /// Renames a user palette; no look names one (#1752).
    public func renamePalette(from old: String, to new: String) throws {
        try paletteLibrary.rename(from: old, to: new)
    }

    /// Saves `settings`' styling and colours as look `name`.
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        let look = ShelfLook(
            name: name,
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings)
        )
        try lookLibrary.save(look)
        return look
    }

    /// Imports a look file under a free name.
    @discardableResult
    public func importLook(
        from url: URL,
        fallbackName: String
    ) throws -> ShelfLook {
        var look = try lookLibrary.importLook(from: url)
        let looks = lookLibrary
        look.name = Self.uniqueName(
            base: Self.named(look.name, else: fallbackName)
        ) { looks.isBuiltinName($0) || looks.hasUserLook($0) }
        try lookLibrary.save(look)
        return look
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
