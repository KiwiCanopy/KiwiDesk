import Foundation

/// The copy a migration keeps of the file it rewrites (#1880), so
/// a downgrade or a faulty step never strands a config file.
///
/// One folder, `migration-backups/` in the config directory,
/// mirroring each file's relative path with `.pre-v<format>`
/// appended: one `ConfigArtifact` case and one `.gitignore` line
/// where the directory is a dotfiles checkout. Written only on a
/// real migration, so a plain read stays a read (#1245).
enum MigrationBackup {
    /// The folder's name in the config directory.
    static let folderName = "migration-backups"

    /// Writes `migrated` over `file` after keeping `original`. The
    /// first copy taken at a format stays; copies of older formats
    /// of the same file are removed, leaving one per file.
    static func write(
        _ migrated: Data,
        replacing original: Data,
        at file: URL,
        configDirectory: URL
    ) {
        keep(original, of: file, configDirectory: configDirectory)
        try? migrated.write(to: file, options: .atomic)
    }

    /// Where `file`'s copy at `format` lives.
    static func url(
        of file: URL,
        format: Int,
        configDirectory: URL
    ) -> URL {
        let root = configDirectory.standardizedFileURL.path
        let path = file.standardizedFileURL.path
        let relative =
            path.hasPrefix(root + "/")
            ? String(path.dropFirst(root.count + 1))
            : file.lastPathComponent
        return
            configDirectory
            .appendingPathComponent(folderName)
            .appendingPathComponent(relative + ".pre-v\(format)")
    }

    private static func keep(
        _ original: Data,
        of file: URL,
        configDirectory: URL
    ) {
        let format = storedFormat(of: original)
        let copy = url(
            of: file,
            format: format,
            configDirectory: configDirectory
        )
        let files = FileManager.default
        guard !files.fileExists(atPath: copy.path) else { return }
        let folder = copy.deletingLastPathComponent()
        try? files.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        let stem = file.lastPathComponent + ".pre-v"
        for name in (try? files.contentsOfDirectory(atPath: folder.path))
            ?? [] where name.hasPrefix(stem)
        {
            try? files.removeItem(at: folder.appendingPathComponent(name))
        }
        try? original.write(to: copy, options: .atomic)
    }

    /// The file's own `format`, 0 where it carries none.
    private static func storedFormat(of data: Data) -> Int {
        let root = try? JSONSerialization.jsonObject(with: data)
        return (root as? [String: Any])?["format"] as? Int ?? 0
    }
}
