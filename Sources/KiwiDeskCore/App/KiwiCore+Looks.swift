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
    /// `LookCatalog.bundled` (`LookCatalogSeamTests`), built once per
    /// set of sizes, since a hover reads it per Space card (#2993).
    public var bundledLooks: [ShelfLook] {
        bundledLooksMemo.looks(
            for: starterSizes(),
            build: LookCatalog.bundled(sizes:)
        )
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
    /// unreadable library (#2860). Answers the name it stored.
    @discardableResult
    public func renameLook(from old: String, to new: String) throws -> String {
        let name = try admittedName(new) {
            lookNameVerdict($0, renaming: old)
        }
        try lookLibrary.rename(from: old, to: name)
        return name
    }

    /// Deletes a saved look (#2860).
    public func deleteLook(_ name: String) throws {
        let library = lookLibrary
        let held = library.userLooks().first { $0.name == name }?.wallpaper
        try library.delete(name)
        trashUnnamedWallpapers(held?.names ?? [])
    }

    /// Saves `settings`' styling and colours as look `name`, with
    /// the credit its origin still earns (#1740); a name
    /// `lookNameVerdict` refuses throws `LibraryNameRefusal`.
    @discardableResult
    public func saveLook(
        named name: String,
        from settings: TilingSettings
    ) throws -> ShelfLook {
        var look = ShelfLook.current(
            named: try admittedName(name) { lookNameVerdict($0) },
            in: settings
        )
        // Save never captures a picture; an overwrite keeps the one
        // the look holds, which only Remove Wallpaper detaches (#3478).
        let library = lookLibrary
        look.wallpaper =
            library.userLooks().first { $0.name == look.name }?.wallpaper
        try library.save(look)
        return look
    }

    /// Writes `look`, which owns its colours (#1752), as a look
    /// file at `url`.
    public func exportLook(
        _ look: ShelfLook,
        to url: URL,
        includingWallpaper: Bool = false
    ) throws {
        var body = look
        var pictures: [String: Data]?
        if includingWallpaper, let wallpaper = look.wallpaper {
            let library = wallpaperLibrary
            pictures = Dictionary(
                uniqueKeysWithValues: wallpaper.names.compactMap { name in
                    library.data(of: name).map { (name, $0) }
                }
            )
        } else {
            // A picture left behind is not named: the file carries
            // no reference it cannot keep (#3478 ▸ Export).
            body.wallpaper = nil
        }
        try lookLibrary.export(
            LookExport(look: body, wallpapers: pictures),
            to: url
        )
    }

    /// Whether the look file at `url` carries pictures, which the
    /// import offers to bring in (#3478).
    public func lookFileCarriesWallpaper(at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(LookPictures.self, from: data)
        else { return false }
        return !(file.wallpapers ?? [:]).isEmpty
    }

    /// Imports a look file under a free name.
    /// `withWallpaper` copies the file's pictures in, each
    /// re-hashed; false brings the look in with none.
    @discardableResult
    public func importLook(
        from url: URL,
        fallbackName: String,
        withWallpaper: Bool = true
    ) throws -> ShelfLook {
        var look = try lookLibrary.importLook(from: url)
        look.wallpaper =
            withWallpaper ? importWallpapers(of: look, from: url) : nil
        return try addImported(look, fallbackName: fallbackName)
    }

    /// The look's picture reference after copying the file's
    /// pictures in, renamed to the hash of the bytes that arrived;
    /// nil where none arrived.
    private func importWallpapers(
        of look: ShelfLook,
        from url: URL
    ) -> LookWallpaper? {
        guard let wallpaper = look.wallpaper,
            let data = try? Data(contentsOf: url),
            let file = try? JSONDecoder().decode(LookPictures.self, from: data)
        else { return nil }
        let library = wallpaperLibrary
        var renamed: [String: String] = [:]
        for (name, bytes) in file.wallpapers ?? [:] {
            if let stored = try? library.add(bytes) { renamed[name] = stored }
        }
        switch wallpaper {
        case .all(let name):
            return renamed[name].map(LookWallpaper.all)
        case .perScreen(let map):
            let kept = map.compactMapValues { renamed[$0] }
            return kept.isEmpty ? nil : .perScreen(kept)
        }
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
        // The gallery stays link-only (#2838): no picture comes in.
        look.wallpaper = nil
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
        let trimmed = LibraryNameVerdict.normalized(name)
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

/// A look file's pictures alone, read beside its body (#3478).
private struct LookPictures: Decodable {
    var wallpapers: [String: Data]?
}
