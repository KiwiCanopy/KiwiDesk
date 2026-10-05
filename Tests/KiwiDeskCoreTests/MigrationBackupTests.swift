import Foundation
import Testing

@testable import KiwiDeskCore

/// A migration keeps the file it rewrites (#1880): the original
/// bytes land in `migration-backups/` under the file's relative
/// path, a plain read writes nothing, and one copy is kept per
/// file.
@Suite("Migration backups (#1880)", .serialized)
@MainActor
struct MigrationBackupTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-migbak-\(UUID().uuidString)")
    }

    /// A current profile from the encoder, stamped one format back,
    /// so the migration runs and the file still decodes.
    private func olderProfile(_ name: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let profile = Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        var root = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(profile))
                as? [String: Any]
        )
        root["format"] = Profile.currentFormat - 1
        return try JSONSerialization.data(withJSONObject: root)
    }

    private func copies(in dir: URL) -> [String] {
        let folder = dir.appendingPathComponent(MigrationBackup.folderName)
        let walker = FileManager.default.enumerator(atPath: folder.path)
        return (walker?.allObjects as? [String] ?? [])
            .filter { $0.contains(".pre-v") }.sorted()
    }

    @Test("a migrated profile read keeps the original bytes")
    func profileReadKeepsTheOriginal() throws {
        let dir = directory()
        let profiles = ProfileManager(
            directory: dir.appendingPathComponent("profiles")
        )
        try FileManager.default.createDirectory(
            at: profiles.directory,
            withIntermediateDirectories: true
        )
        let original = try olderProfile("Work")
        let file = profiles.directory.appendingPathComponent("Work.json")
        try original.write(to: file)
        _ = try profiles.read(name: "Work")
        let format = Profile.currentFormat - 1
        let copy = MigrationBackup.url(
            of: file,
            format: format,
            configDirectory: dir
        )
        #expect(try Data(contentsOf: copy) == original)
        #expect(copies(in: dir) == ["profiles/Work.json.pre-v\(format)"])
        // The rewrite landed, so a second read migrates nothing.
        try FileManager.default.removeItem(at: copy)
        _ = try profiles.read(name: "Work")
        #expect(copies(in: dir).isEmpty)
    }

    @Test("one copy per file: a format's first copy stays")
    func oneCopyPerFile() throws {
        let dir = directory()
        let file = dir.appendingPathComponent("gui.json")
        func stamped(_ format: Int, _ tag: String) -> Data {
            Data(#"{"format":\#(format),"tag":"\#(tag)"}"#.utf8)
        }
        MigrationBackup.write(
            stamped(5, "new"),
            replacing: stamped(3, "first"),
            at: file,
            configDirectory: dir
        )
        MigrationBackup.write(
            stamped(5, "new"),
            replacing: stamped(3, "second"),
            at: file,
            configDirectory: dir
        )
        let three = MigrationBackup.url(
            of: file,
            format: 3,
            configDirectory: dir
        )
        #expect(try Data(contentsOf: three) == stamped(3, "first"))
        MigrationBackup.write(
            stamped(6, "newer"),
            replacing: stamped(4, "later"),
            at: file,
            configDirectory: dir
        )
        #expect(copies(in: dir) == ["gui.json.pre-v4"])
        #expect(try Data(contentsOf: file) == stamped(6, "newer"))
    }
}
