import Foundation

/// One policy for a corrupt config file (#2324 ruling 13): a file
/// that is neither readable nor a newer build's is overwritten by
/// its store's next write, after one copy goes into this Mac's
/// `migration-backups/` as `<path>.corrupt`. A newer file never
/// reaches here: its door refused first (`NewerFormatOnDisk`).
enum CorruptFile {
    /// The copy's suffix beside the file's relative path.
    static let suffix = ".corrupt"

    /// Before a write over `file`: keeps its copy where it exists
    /// and `reads` refuses its bytes. A nil `backups` — a store
    /// built outside a core — keeps none.
    static func keepBeforeOverwrite(
        _ file: URL,
        in backups: URL?,
        reads: (Data) -> Bool
    ) {
        guard let data = try? Data(contentsOf: file), !reads(data)
        else { return }
        keep(data, of: file, in: backups)
    }

    /// `keepBeforeOverwrite` for a file `T` decodes, migrated
    /// first where `migrating`, as its reader does.
    static func keepBeforeOverwrite<T: Decodable>(
        _ file: URL,
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder(),
        migrating: Bool = true,
        in backups: URL?
    ) {
        keepBeforeOverwrite(file, in: backups) { data in
            let input =
                migrating ? ConfigMigration.migrated(data) ?? data : data
            return (try? decoder.decode(type, from: input)) != nil
        }
    }

    /// Keeps `data` as `file`'s ONE corrupt copy, replacing an
    /// earlier one; a copy that fails to land is logged nowhere,
    /// since the write it precedes goes ahead (the ruling's cost).
    static func keep(_ data: Data, of file: URL, in backups: URL?) {
        guard let backups else { return }
        let copy = MigrationBackup.url(of: file, suffix: suffix, in: backups)
        try? FileManager.default.createDirectory(
            at: copy.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: copy, options: .atomic)
    }
}
