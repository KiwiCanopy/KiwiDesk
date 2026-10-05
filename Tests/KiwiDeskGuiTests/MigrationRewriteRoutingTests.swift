import Foundation
import Testing

/// A reader that REWRITES a migrated config file does so through
/// `MigrationBackup.migrateInPlace` alone (#1880), which keeps the
/// original first; a reader that migrates in memory names
/// `ConfigMigration.migrated` and writes nothing. Every reader is
/// in `ConfigMigrationRoutingTests`' census; this splits it by
/// what the read does to the file. The #1741 adoption's strip of
/// retired keys rewrites profiles outside this door by ruling:
/// its values have just landed in `gui.json`, so no copy is owed.
@Suite("Migration rewrite routing (#1880)")
struct MigrationRewriteRoutingTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Readers whose read rewrites the file it migrated.
    private let rewriters: Set<String> = [
        "Config/GuiConfigStore.swift",
        "Appearance/PaletteStore.swift",
        "Appearance/LookStore.swift",
        "Profiles/ProfileManager.swift",
    ]
    /// Readers that migrate in memory only: the settle's crossing
    /// check would stamp the file it asks about (#1530), and a
    /// backup is never rewritten.
    private let inMemory: Set<String> = [
        "Profiles/ProfileManager+Settle.swift",
        "App/KiwiCore+Backup.swift",
    ]

    private func source(_ relative: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: Self.core.appendingPathComponent(relative),
                encoding: .utf8
            )
        )
    }

    @Test("a rewriting reader migrates through the door alone")
    func rewritersTakeTheDoor() throws {
        for file in rewriters {
            let text = try source(file)
            #expect(
                text.contains("MigrationBackup.migrateInPlace("),
                "\(file)"
            )
            #expect(!text.contains("ConfigMigration.migrated("), "\(file)")
        }
    }

    @Test("an in-memory reader writes no migrated bytes")
    func inMemoryReadersWriteNothing() throws {
        for file in inMemory {
            let text = try source(file)
            #expect(text.contains("ConfigMigration.migrated("), "\(file)")
            #expect(!text.contains("migrateInPlace("), "\(file)")
        }
    }

    /// A new migrating reader is classified here before it lands.
    @Test("every migrating file is classified")
    func everyMigratingFileIsClassified() throws {
        let prefix = Self.core.path + "/"
        var migrating: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            guard
                text.contains("ConfigMigration.migrated(")
                    || text.contains("MigrationBackup.migrateInPlace(")
            else { continue }
            migrating.insert(String(file.path.dropFirst(prefix.count)))
        }
        #expect(
            migrating
                == rewriters.union(inMemory)
                .union(["Config/MigrationBackup.swift"])
        )
    }
}
