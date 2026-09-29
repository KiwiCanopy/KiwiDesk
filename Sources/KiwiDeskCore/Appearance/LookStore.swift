import Foundation

/// Global look library store managing `looks.json` (#1684) — the
/// palette library's twin (`PaletteStore`), stateless so every
/// read is the file.
public final class LookStore {
    public enum StoreError: Error, Equatable {
        case reservedName(String)
        case notFound(String)
        case duplicateName(String)
        case invalidFile
        /// Unreadable or newer-format library.
        case unreadableLibrary
    }

    private let fileURL: URL

    /// URL to `looks.json`.
    public var url: URL { fileURL }

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("looks.json")
    }

    /// Decodes the document, running `ConfigMigration` if needed,
    /// then the #1752 colour carry, which a byte step cannot do.
    private func readDocument() throws -> LookDocument? {
        guard var data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        if let migrated = ConfigMigration.migrated(data) {
            data = migrated
            try? migrated.write(to: fileURL, options: .atomic)
        }
        if LookColorCarry.isOwed(data) {
            data = try carried(data)
        }
        guard
            let doc = try? JSONDecoder().decode(
                LookDocument.self,
                from: data
            )
        else { throw StoreError.unreadableLibrary }
        return doc
    }

    /// `data` with its colours carried in and written back. An
    /// unreadable palette library stands the carry down, the old
    /// file untouched: the names cannot be told from gone ones.
    private func carried(_ data: Data) throws -> Data {
        let palettes = PaletteStore(
            directory: fileURL.deletingLastPathComponent()
        )
        guard let saved = try? palettes.libraryPalettes(),
            let carried = LookColorCarry.carriedLibrary(
                data,
                palettes: palettes.builtins() + saved
            )
        else { throw StoreError.unreadableLibrary }
        try? carried.write(to: fileURL, options: .atomic)
        return carried
    }

    /// User looks for mutating paths (throws on an unreadable library).
    public func libraryLooks() throws -> [ShelfLook] {
        try readDocument()?.looks ?? []
    }

    /// User looks for read queries (empty on error).
    public func userLooks() -> [ShelfLook] {
        (try? libraryLooks()) ?? []
    }

    public func isBuiltinName(_ name: String) -> Bool {
        LookCatalog.bundledNames.contains(name)
    }

    public func hasUserLook(_ name: String) -> Bool {
        userLooks().contains { $0.name == name }
    }

    /// Saves or updates a user look.
    public func save(_ look: ShelfLook) throws {
        guard !isBuiltinName(look.name) else {
            throw StoreError.reservedName(look.name)
        }
        var looks = try libraryLooks()
        if let index = looks.firstIndex(where: { $0.name == look.name }) {
            looks[index] = look
        } else {
            looks.append(look)
        }
        try write(looks)
    }

    /// Bulk-replaces the user library on a backup restore — the
    /// untrusted entry point, so it enforces every single-item
    /// invariant by DROPPING (a built-in's name, a duplicate,
    /// unknown styling keys) and returns how many were refused.
    @discardableResult
    public func replaceUserLooks(with looks: [ShelfLook]) throws -> Int {
        var seen: Set<String> = []
        var admissible: [ShelfLook] = []
        for look in looks {
            guard !isBuiltinName(look.name),
                seen.insert(look.name).inserted
            else { continue }
            admissible.append(Self.filtered(look))
        }
        try write(admissible)
        return looks.count - admissible.count
    }

    public func delete(_ name: String) throws {
        var looks = try libraryLooks()
        guard let index = looks.firstIndex(where: { $0.name == name })
        else { throw StoreError.notFound(name) }
        looks.remove(at: index)
        try write(looks)
    }

    public func rename(from: String, to: String) throws {
        guard !isBuiltinName(to) else {
            throw StoreError.reservedName(to)
        }
        guard to == from || !hasUserLook(to) else {
            throw StoreError.duplicateName(to)
        }
        var looks = try libraryLooks()
        guard let index = looks.firstIndex(where: { $0.name == from })
        else { throw StoreError.notFound(from) }
        looks[index].name = to
        try write(looks)
    }

    public func export(_ file: LookExport, to url: URL) throws {
        try Self.encoder.encode(file).write(to: url)
    }

    /// Imports a look file — one from before #1752 carried against
    /// the palette it travelled with, then `palettes` — filtering
    /// styling to `LookKeys` and colours to known palette paths.
    public func importLook(
        from url: URL,
        palettes: [ColorPalette]
    ) throws -> ShelfLook {
        guard let data = try? Data(contentsOf: url) else {
            throw StoreError.invalidFile
        }
        if let file = try? JSONDecoder().decode(
            LookExport.self,
            from: data
        ) {
            return Self.filtered(file.look)
        }
        guard
            let look = LookColorCarry.importedLegacy(
                data,
                palettes: palettes
            )
        else { throw StoreError.invalidFile }
        return Self.filtered(look)
    }

    /// `look` with styling keys outside `LookKeys` and colours
    /// outside `ColorPaletteKeys` dropped.
    static func filtered(_ look: ShelfLook) -> ShelfLook {
        let style = Set(LookKeys.all)
        let colors = Set(ColorPaletteKeys.all)
        return ShelfLook(
            name: look.name,
            style: look.style.filter { style.contains($0.key) },
            colors: look.colors.filter { colors.contains($0.key) }
        )
    }

    private static var encoder: JSONEncoder { LookDocument.encoder }

    private func write(_ looks: [ShelfLook]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Atomic: a truncated library decodes as unreadable, and a
        // later save would otherwise rewrite it with one look.
        try Self.encoder.encode(LookDocument(looks: looks)).write(
            to: fileURL,
            options: .atomic
        )
    }
}
