import Foundation
import Testing

@testable import KiwiDeskCore

/// A migration keeps the file it rewrites (#1880): the original
/// lands in `migration-backups/` under the file's relative path,
/// one copy per file — the latest pre-migration bytes — and the
/// rewrite waits for the copy. A store built outside a core keeps
/// none, so no fixture writes beside its scratch directory.
@Suite("Migration backups (#1880)", .serialized)
@MainActor
struct MigrationBackupTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-migbak-\(UUID().uuidString)")
    }

    /// A current profile from the encoder, stamped `back` formats
    /// older, so the migration runs and the file still decodes.
    private func olderProfile(
        _ name: String,
        back: Int = 1,
        monitor: String = "A:100x100"
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let profile = Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [monitor])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(profile))
                as? [String: Any]
        )
        root["format"] = Profile.currentFormat - back
        return try JSONSerialization.data(withJSONObject: root)
    }

    private func copies(in dir: URL) -> [String] {
        let folder = dir.appendingPathComponent(MigrationBackup.folderName)
        let walker = FileManager.default.enumerator(atPath: folder.path)
        return (walker?.allObjects as? [String] ?? [])
            .filter { $0.contains(".pre-v") }.sorted()
    }

    private func store(in dir: URL, _ name: String, _ bytes: Data) throws
        -> ProfileManager
    {
        let profiles = KiwiCore.makeProfileManager(in: dir)
        try FileManager.default.createDirectory(
            at: profiles.directory,
            withIntermediateDirectories: true
        )
        try bytes.write(
            to: profiles.directory.appendingPathComponent("\(name).json")
        )
        return profiles
    }

    @Test("a migrated profile read keeps the original bytes")
    func profileReadKeepsTheOriginal() throws {
        let dir = directory()
        let original = try olderProfile("Work")
        let profiles = try store(in: dir, "Work", original)
        _ = try profiles.read(name: "Work")
        let format = Profile.currentFormat - 1
        let copy = MigrationBackup.url(
            of: profiles.directory.appendingPathComponent("Work.json"),
            format: format,
            in: KiwiCore.migrationBackups(in: dir)
        )
        #expect(try Data(contentsOf: copy) == original)
        #expect(copies(in: dir) == ["profiles/Work.json.pre-v\(format)"])
        // The rewrite landed, so a second read migrates nothing.
        try FileManager.default.removeItem(at: copy)
        _ = try profiles.read(name: "Work")
        #expect(copies(in: dir).isEmpty)
    }

    @Test("one copy per file: the latest original")
    func latestCopyIsKept() throws {
        let dir = directory()
        let older = try olderProfile("Work", back: 2)
        let profiles = try store(in: dir, "Work", older)
        _ = try profiles.read(name: "Work")
        // A downgrade wrote the file at an older format again, then
        // an edit there; the copy is that edit, not the first one.
        _ = try profiles.read(name: "Work")
        try olderProfile("Work", back: 1).write(
            to: profiles.directory.appendingPathComponent("Work.json")
        )
        _ = try profiles.read(name: "Work")
        let later = try olderProfile("Work", back: 1, monitor: "B:1x1")
        try later.write(
            to: profiles.directory.appendingPathComponent("Work.json")
        )
        _ = try profiles.read(name: "Work")
        let format = Profile.currentFormat - 1
        #expect(copies(in: dir) == ["profiles/Work.json.pre-v\(format)"])
        let copy = MigrationBackup.url(
            of: profiles.directory.appendingPathComponent("Work.json"),
            format: format,
            in: KiwiCore.migrationBackups(in: dir)
        )
        #expect(try Data(contentsOf: copy) == later)
    }

    @Test("a copy that cannot land leaves the file as it was")
    func failedCopyKeepsTheFile() throws {
        let dir = directory()
        let original = try olderProfile("Work")
        let profiles = try store(in: dir, "Work", original)
        // A FILE where the folder belongs refuses the copy.
        try Data().write(to: KiwiCore.migrationBackups(in: dir))
        _ = try profiles.read(name: "Work")
        let file = profiles.directory.appendingPathComponent("Work.json")
        #expect(try Data(contentsOf: file) == original)
    }

    @Test("a store built outside a core keeps no copy")
    func bareStoreKeepsNone() throws {
        let dir = directory()
        let profiles = ProfileManager(
            directory: dir.appendingPathComponent("profiles")
        )
        try FileManager.default.createDirectory(
            at: profiles.directory,
            withIntermediateDirectories: true
        )
        try olderProfile("Work").write(
            to: profiles.directory.appendingPathComponent("Work.json")
        )
        _ = try profiles.read(name: "Work")
        #expect(copies(in: dir).isEmpty)
        #expect(
            !FileManager.default.fileExists(
                atPath: KiwiCore.migrationBackups(in: dir).path
            )
        )
    }
}
