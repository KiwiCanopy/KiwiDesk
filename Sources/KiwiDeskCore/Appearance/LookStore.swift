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

    /// Read-only built-in looks.
    public func builtins() -> [ShelfLook] {
        LookCatalog.bundled()
    }

    /// Decodes the document, running `ConfigMigration` if needed.
    private func readDocument() throws -> LookDocument? {
        guard var data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        if let migrated = ConfigMigration.migrated(data) {
            data = migrated
            try? migrated.write(to: fileURL, options: .atomic)
        }
        guard
            let doc = try? JSONDecoder().decode(
                LookDocument.self,
                from: data
            )
        else { throw StoreError.unreadableLibrary }
        return doc
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
        builtins().contains { $0.name == name }
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

    /// Points every user look naming palette `from` at `to` — a
    /// palette rename keeps the looks drawn in it.
    public func repointPalette(from: String, to: String) throws {
        var looks = try libraryLooks()
        guard looks.contains(where: { $0.palette == from }) else {
            return
        }
        for index in looks.indices where looks[index].palette == from {
            looks[index].palette = to
        }
        try write(looks)
    }

    public func export(_ file: LookExport, to url: URL) throws {
        try Self.encoder.encode(file).write(to: url)
    }

    /// Imports a look file, filtering styling to `LookKeys` and
    /// colours to known palette paths.
    public func importLook(from url: URL) throws -> LookExport {
        guard let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode(
                LookExport.self,
                from: data
            )
        else { throw StoreError.invalidFile }
        let known = Set(ColorPaletteKeys.all)
        let palette = raw.palette.map {
            ColorPalette(
                name: $0.name,
                colors: $0.colors.filter { known.contains($0.key) }
            )
        }
        return LookExport(look: Self.filtered(raw.look), palette: palette)
    }

    /// `look` with styling keys outside `LookKeys` dropped.
    static func filtered(_ look: ShelfLook) -> ShelfLook {
        let known = Set(LookKeys.all)
        return ShelfLook(
            name: look.name,
            palette: look.palette,
            style: look.style.filter { known.contains($0.key) }
        )
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

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
