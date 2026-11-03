import Foundation

/// The look library's Core doors (#1684), in the palette doors'
/// shape (#2952): a look owns its colours (#1752), so the two
/// libraries never reach into each other; the GUI reads and writes
/// looks through here and never holds the store
/// (`LookDoorSeamTests`), and a store refuses while its own file is
/// unreadable.
extension KiwiCore {
    /// The look library, built on demand — stateless like
    /// `paletteLibrary`.
    var lookLibrary: LookStore {
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

    /// The saved user looks, read from disk.
    public var userLooks: [ShelfLook] {
        lookLibrary.userLooks()
    }

    /// `base`, trimmed, or the first `base N` no bundled or user
    /// look holds.
    public func freeLookName(base: String) -> String {
        let library = lookLibrary
        return Self.uniqueName(base: LibraryNameVerdict.normalized(base)) {
            library.isBuiltinName($0) || library.hasUserLook($0)
        }
    }

    /// Renames a saved look; a name `lookNameVerdict` refuses
    /// throws `LibraryNameRefusal`, and the store refuses an
    /// unreadable library (#2860).
    public func renameLook(from old: String, to new: String) throws {
        let name = try admittedName(
            new,
            lookNameVerdict(new, renaming: old)
        )
        try lookLibrary.rename(from: old, to: name)
    }

    /// Deletes a saved look (#2860).
    public func deleteLook(_ name: String) throws {
        try lookLibrary.delete(name)
    }

    /// Saves `settings`' styling and colours as look `name`, with
    /// the credit its origin still earns (#1740); a name
    /// `lookNameVerdict` refuses throws `LibraryNameRefusal`.
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        let look = ShelfLook.current(
            named: try admittedName(name, lookNameVerdict(name)),
            in: settings
        )
        try lookLibrary.save(look)
        return look
    }

    /// Writes `look`, which owns its colours (#1752), as a look
    /// file at `url`.
    public func exportLook(_ look: ShelfLook, to url: URL) throws {
        try lookLibrary.export(LookExport(look: look), to: url)
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
    /// A gallery id My looks already holds answers with that look
    /// and saves no copy (`heldGalleryLook`, #2943).
    @discardableResult
    public func installGalleryLook(
        _ data: Data,
        from link: LookLink,
        fallbackName: String
    ) throws -> ShelfLook {
        if let held = heldGalleryLook(for: link) { return held }
        var look = try LookStore.importLook(data: data)
        look.galleryID = link.id
        return try addImported(look, fallbackName: fallbackName)
    }

    /// The look My looks holds under `link`'s gallery id, as the user
    /// keeps it — the first in store order where copies exist
    /// (#2943). Asked before a download, so a re-add needs no network.
    public func heldGalleryLook(for link: LookLink) -> ShelfLook? {
        lookLibrary.userLooks().first { $0.galleryID == link.id }
    }

    private func addImported(
        _ imported: ShelfLook,
        fallbackName: String
    ) throws -> ShelfLook {
        var look = imported
        look.name = freeLookName(
            base: Self.named(look.name, else: fallbackName)
        )
        try lookLibrary.save(look)
        return look
    }

    /// `name` trimmed, or `fallback` when nothing is left.
    static func named(_ name: String, else fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// `base`, then `base 2`, `base 3`, … skipping taken names.
    static func uniqueName(
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
