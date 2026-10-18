import Foundation
import Testing

@testable import KiwiDeskCore

/// A profile's stable id (#2324 ruling 11): a legacy file is
/// stamped the SAME id on every Mac, the write door keeps the id a
/// file already carries and refuses to let a second file share it,
/// and the index names one keeper per id.
@MainActor
@Suite("Profile ids (#2324)")
struct ProfileIDTests {
    private func manager() -> ProfileManager {
        ProfileManager(
            directory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-ids-\(UUID().uuidString)")
        )
    }

    private func profile(_ name: String, id: ProfileID = .fresh()) -> Profile {
        Profile(
            id: id,
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("A legacy id is the name's, the same everywhere, and no name")
    func legacyIsDeterministic() {
        let work = ProfileID.legacy(name: "Work")
        #expect(work == ProfileID.legacy(name: "Work"))
        #expect(work != ProfileID.legacy(name: "Home"))
        #expect(UUID(uuidString: work.raw) != nil)
        #expect(work.raw != "Work")
    }

    /// The migration reaches a profile file and a bundle's inline
    /// profiles, both with the legacy id.
    @Test("An id-less profile is stamped its legacy id")
    func migrationStampsLegacyID() throws {
        let file = Data(
            #"{"format":22,"name":"Work","monitor_sets":[]}"#.utf8
        )
        let migrated = try #require(ConfigMigration.migrated(file))
        let root = try #require(
            JSONSerialization.jsonObject(with: migrated) as? [String: Any]
        )
        #expect(root["id"] as? String == ProfileID.legacy(name: "Work").raw)
        let bundle = Data(
            #"{"format":28,"writtenBy":"t","palettes":[],"#
                + #""profiles":[{"name":"A","monitor_sets":[]}]}"#
                .utf8
        )
        let lifted = try #require(ConfigMigration.migrated(bundle))
        let out = try #require(
            JSONSerialization.jsonObject(with: lifted) as? [String: Any]
        )
        let first = try #require((out["profiles"] as? [[String: Any]])?.first)
        #expect(first["id"] as? String == ProfileID.legacy(name: "A").raw)
    }

    /// Every builder hands the door a fresh id; the file's own
    /// survives, or a Save would orphan every binding.
    @Test("Overwriting a file keeps the id it carries")
    func overwriteKeepsTheID() throws {
        let profiles = manager()
        let first = try profiles.write(profile("Work"))
        let again = try profiles.write(profile("Work"))
        #expect(again.id == first.id)
        #expect(try profiles.read(name: "Work").id == first.id)
    }

    /// A Finder duplicate or a copy brings the id along; the new
    /// file takes a fresh one.
    @Test("A second file never takes an id another keeps")
    func takenIDIsReminted() throws {
        let profiles = manager()
        let work = try profiles.write(profile("Work"))
        let copy = try profiles.write(profile("Copy", id: work.id))
        #expect(copy.id != work.id)
        #expect(profiles.profileName(withID: work.id) == "Work")
        #expect(profiles.profileName(withID: copy.id) == "Copy")
    }

    @Test("A rename keeps the id")
    func renameKeepsTheID() throws {
        let profiles = manager()
        let work = try profiles.write(profile("Work"))
        try profiles.rename(from: "Work", to: "Office")
        #expect(try profiles.read(name: "Office").id == work.id)
        #expect(profiles.profileName(withID: work.id) == "Office")
    }

    /// Two files carrying one id: the one whose stored name is its
    /// own file name keeps it; otherwise the lowest file name.
    @Test("The index names one keeper per id")
    func indexKeeper() {
        let shared = ProfileID.fresh()
        let index = ProfileIndex([
            ("Work copy", profile("Work", id: shared)),
            ("Work", profile("Work", id: shared)),
        ])
        #expect(index.file(of: shared) == "Work")
        let tie = ProfileIndex([
            ("B", profile("X", id: shared)),
            ("A", profile("Y", id: shared)),
        ])
        #expect(tie.file(of: shared) == "A")
    }
}
