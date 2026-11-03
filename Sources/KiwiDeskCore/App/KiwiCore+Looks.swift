import Foundation

/// The look library's Core doors (#1684). A look owns its colours
/// (#1752), so the look and palette libraries never reach into
/// each other; a write still goes through here, never a store call
/// at a GUI site, and a store refuses while its own file is
/// unreadable.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`, and public so the GUI reads Core's one
    /// store rather than building its own.
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

    /// Renames a saved look; the store refuses a bundled or taken
    /// name and an unreadable library (#2860).
    public func renameLook(from old: String, to new: String) throws {
        try lookLibrary.rename(from: old, to: new)
    }

    /// Deletes a saved look (#2860).
    public func deleteLook(_ name: String) throws {
        try lookLibrary.delete(name)
    }

    /// Saves `settings`' styling and colours as look `name`, with
    /// the credit its origin still earns (#1740).
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        let look = ShelfLook.current(named: name, in: settings)
        try lookLibrary.save(look)
        return look
    }

    /// Imports a look file under a free name.
    @discardableResult
    public func importLook(
        from url: URL,
        fallbackName: String
    ) throws -> ShelfLook {
        try addImported(
            lookLibrary.importLook(from: url),
            fallbackName: fallbackName
        )
    }

    /// Adds a look a gallery link downloaded (#1740) under a free
    /// name, keeping the gallery id a look started from it credits.
    /// A gallery id My looks already holds answers with that look,
    /// as the user keeps it, and saves no copy (#2943).
    @discardableResult
    public func installGalleryLook(
        _ data: Data,
        from link: LookLink,
        fallbackName: String
    ) throws -> ShelfLook {
        if let held = lookLibrary.userLooks().first(where: {
            $0.galleryID == link.id
        }) {
            return held
        }
        var look = try LookStore.importLook(data: data)
        look.galleryID = link.id
        return try addImported(look, fallbackName: fallbackName)
    }

    private func addImported(
        _ imported: ShelfLook,
        fallbackName: String
    ) throws -> ShelfLook {
        var look = imported
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
