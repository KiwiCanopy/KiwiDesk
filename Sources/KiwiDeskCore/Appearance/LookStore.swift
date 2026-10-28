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
        /// A look file a newer build wrote (#1740), its format.
        case newerLookFile(Int)
        /// Unreadable or newer-format library.
        case unreadableLibrary
    }

    private let fileURL: URL

    /// URL to `looks.json`.
    public var url: URL { fileURL }

    /// Where a migrated rewrite keeps the original (#1880), set by
    /// the core that owns the config directory; nil keeps none.
    var migrationBackups: URL?

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("looks.json")
    }

    /// Decodes the document, running `ConfigMigration` if needed.
    /// Raw, so a rewrite keeps what a newer build stored; a look
    /// read for use is admitted in `userLooks`.
    private func readDocument() throws -> LookDocument? {
        guard var data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        data = MigrationBackup.migrateInPlace(
            data,
            at: fileURL,
            backups: migrationBackups
        )
        guard
            let doc = try? JSONDecoder().decode(
                LookDocument.self,
                from: data
            )
        else { throw StoreError.unreadableLibrary }
        return doc
    }

    /// User looks RAW, for the store's own rewrites and a backup's
    /// export (throws on an unreadable library): a newer build's
    /// keys survive them (`LookStoreTests` ▸ `rewriteKeepsUnknownKeys`).
    /// Core-only; a reader that uses a look takes `userLooks`.
    func libraryLooks() throws -> [ShelfLook] {
        try readDocument()?.looks ?? []
    }

    /// User looks for read queries (empty on error), each as every
    /// reader takes it (`ShelfLook.admitted`).
    public func userLooks() -> [ShelfLook] {
        ((try? libraryLooks()) ?? []).map(\.admitted)
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
        var looks = try writableLibrary()
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
            admissible.append(look.admitted)
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

    /// Imports a look file, admitted (`ShelfLook.admitted`), with
    /// its credit. A file below the current format crosses in memory
    /// through the look-path steps, since a markerless sidecar has no
    /// stamp to end on (profiles.md); a newer one is refused.
    public func importLook(from url: URL) throws -> ShelfLook {
        guard let data = try? Data(contentsOf: url) else {
            throw StoreError.invalidFile
        }
        return try Self.importLook(data: data)
    }

    /// `importLook(from:)` over bytes already in hand — a file, or a
    /// gallery download (#1740).
    public static func importLook(data: Data) throws -> ShelfLook {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { throw StoreError.invalidFile }
        let format = root["format"] as? Int ?? 0
        guard format <= LookDocument.currentFormat else {
            throw StoreError.newerLookFile(format)
        }
        let crossed =
            format < LookDocument.currentFormat
            ? ConfigMigration.crossingLookExport(data) : data
        guard
            let file = try? JSONDecoder().decode(
                LookExport.self,
                from: crossed
            )
        else { throw StoreError.invalidFile }
        return file.credited.admitted
    }

    private static var encoder: JSONEncoder { LookDocument.encoder }

    private func write(_ looks: [ShelfLook]) throws {
        keepCorrupt()
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

    /// The library a save starts from (#2324 ruling 13): a newer
    /// build's still refuses, while a corrupt one starts empty and
    /// `write` keeps its copy. A delete or rename reads through
    /// `libraryLooks`, since a corrupt library holds nothing to name.
    private func writableLibrary() throws -> [ShelfLook] {
        do {
            return try libraryLooks()
        } catch StoreError.unreadableLibrary
            where newerFormat() == nil
        {
            return []
        }
    }

    /// The library a newer build wrote, if it did (#2325) — the
    /// one pairing of this file with its format.
    public func newerFormat() -> NewerFormatOnDisk? {
        NewerFormatOnDisk.check(
            fileURL,
            .looks,
            knows: LookDocument.currentFormat
        )
    }

    /// Keeps a corrupt library's copy before `write` replaces it;
    /// a newer one reaching here is a restore's, which discarded
    /// the file first, and is not corrupt.
    private func keepCorrupt() {
        guard newerFormat() == nil else { return }
        CorruptFile.keepBeforeOverwrite(
            fileURL,
            as: LookDocument.self,
            in: migrationBackups
        )
    }
}
