import Foundation

/// The one door a store rewrites a migrated config file through,
/// keeping the original first (#1880) so a downgrade or a faulty
/// step never strands the file.
///
/// The copies live in ONE folder, `migration-backups/` in the
/// config directory, each under its file's relative path with
/// `.pre-v<format>` appended — one `ConfigArtifact` case, one
/// `.gitignore` line, nothing for a scan of `profiles/` to skip.
/// Only a real migration writes, so a plain read stays a read
/// (#1245).
enum MigrationBackup {
    /// The folder's name in the config directory.
    static let folderName = "migration-backups"

    /// `data` migrated by `ConfigMigration`, rewritten over `file`
    /// once its original is kept in `backups`; `data` itself when
    /// nothing migrates. A copy that fails to land leaves the file
    /// as it was (the next read migrates again). A nil `backups` —
    /// a store built outside a core — keeps no copy.
    static func migrateInPlace(
        _ data: Data,
        at file: URL,
        backups: URL?
    ) -> Data {
        guard let migrated = ConfigMigration.migrated(data) else {
            return data
        }
        if let backups, !keep(data, of: file, in: backups) {
            return migrated
        }
        try? migrated.write(to: file, options: .atomic)
        return migrated
    }

    /// Where `file`'s copy at `format` lives in `backups`.
    static func url(of file: URL, format: Int, in backups: URL) -> URL {
        let root = backups.deletingLastPathComponent()
            .standardizedFileURL.path
        let path = file.standardizedFileURL.path
        let relative =
            path.hasPrefix(root + "/")
            ? String(path.dropFirst(root.count + 1))
            : file.lastPathComponent
        return backups.appendingPathComponent(
            relative + ".pre-v\(format)"
        )
    }

    /// Keeps `original` as the file's ONE copy — the latest
    /// pre-migration bytes, replacing any older-format copy.
    private static func keep(
        _ original: Data,
        of file: URL,
        in backups: URL
    ) -> Bool {
        let copy = url(
            of: file,
            format: storedFormat(of: original),
            in: backups
        )
        let folder = copy.deletingLastPathComponent()
        let files = FileManager.default
        do {
            try files.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            try original.write(to: copy, options: .atomic)
        } catch {
            return false
        }
        let stem = file.lastPathComponent + ".pre-v"
        for name in (try? files.contentsOfDirectory(atPath: folder.path))
            ?? []
        where name.hasPrefix(stem)
            && name != copy.lastPathComponent
        {
            try? files.removeItem(at: folder.appendingPathComponent(name))
        }
        return true
    }

    /// The file's own `format`, 0 where it carries none.
    private static func storedFormat(of data: Data) -> Int {
        let root = try? JSONSerialization.jsonObject(with: data)
        return (root as? [String: Any])?["format"] as? Int ?? 0
    }
}
