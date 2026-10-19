import Foundation
import Testing

@testable import KiwiDeskCore

/// The pass's decision (#2324 slice 3), over hash maps alone: a
/// file one side changed goes to the other, a file both changed
/// stops the pass, and with no agreement only equal sides or an
/// empty folder settle.
@Suite("A sync pass copies what one side changed")
struct SyncPlanTests {
    @Test("A change here goes out; a change there comes in")
    func oneSidedChangesCross() {
        let plan = SyncPlan.plan(
            here: ["gui.json": "b", "looks.json": "l"],
            folder: ["gui.json": "a", "looks.json": "m"],
            agreed: ["gui.json": "a", "looks.json": "l"]
        )
        #expect(plan.push == ["gui.json"])
        #expect(plan.pull == ["looks.json"])
        #expect(plan.diverged.isEmpty)
    }

    @Test("A deletion on one side removes the file on the other")
    func deletionsCross() {
        let plan = SyncPlan.plan(
            here: ["profiles/A.json": "a"],
            folder: ["profiles/B.json": "b"],
            agreed: ["profiles/A.json": "a", "profiles/B.json": "b"]
        )
        #expect(plan.removeFromFolder == ["profiles/B.json"])
        #expect(plan.removeHere == ["profiles/A.json"])
    }

    @Test("Equal sides copy nothing, whatever the agreement says")
    func equalSidesAreQuiet() {
        let plan = SyncPlan.plan(
            here: ["gui.json": "x"],
            folder: ["gui.json": "x"],
            agreed: ["gui.json": "old"]
        )
        #expect(plan == SyncPlan())
    }

    @Test("A file both sides changed stops the whole pass")
    func bothChangedDiverges() {
        let plan = SyncPlan.plan(
            here: ["gui.json": "b", "looks.json": "n"],
            folder: ["gui.json": "c", "looks.json": "l"],
            agreed: ["gui.json": "a", "looks.json": "l"]
        )
        #expect(plan.diverged == ["gui.json"])
        #expect(plan.copiesNothing)
    }

    @Test("With no agreement, an empty folder takes this Mac's")
    func noAgreementEmptyFolderPushes() {
        let plan = SyncPlan.plan(
            here: ["gui.json": "a", "init.lua": "l"],
            folder: [:],
            agreed: nil
        )
        #expect(plan.push == ["gui.json", "init.lua"])
    }

    @Test("With no agreement, differing sides diverge")
    func noAgreementDiffersDiverges() {
        let plan = SyncPlan.plan(
            here: ["gui.json": "a"],
            folder: ["gui.json": "b"],
            agreed: nil
        )
        #expect(plan.diverged == ["gui.json"])
        #expect(plan.copiesNothing)
    }
}

/// Which names a folder pass reads (#2324 slice 3): the setup's,
/// never a conflict copy, a placeholder or a temporary.
@Suite("A sync pass reads only the setup's names")
struct SyncScanTests {
    private func folder(_ files: [String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-sync-scan-\(UUID().uuidString)")
        for file in files {
            let url = root.appendingPathComponent(file)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(file.utf8).write(to: url)
        }
        return root
    }

    @Test("Setup files and profiles are synced; the rest is not")
    func syncedPaths() throws {
        let root = try folder([
            "gui.json", "init.lua", "palettes.json", "looks.json",
            "profiles/Work.json", "profiles/~Work.json", "sync.json",
            "notes.txt",
            "gui 2.json", ".gui.json.icloud", "profiles/.DS_Store",
            "profiles/Work (conflicted copy 2026-10-19).json",
            ".kiwidesk-incoming-1", "machine.json",
        ])
        #expect(
            SyncScan.syncedPaths(in: root) == [
                "gui.json", "init.lua", "looks.json", "palettes.json",
                "profiles/Work.json",
            ]
        )
        #expect(Set((SyncScan.hashes(in: root) ?? [:]).keys).count == 5)
    }

    @Test("Each sync app's conflict copy is reported")
    func conflictCopies() throws {
        let root = try folder([
            "gui.json", "gui 2.json", "init 3.lua",
            "looks.sync-conflict-20261019-120000-ABCDEFG.json",
            "palettes (Mac's conflicted copy).json", "guide.json",
            "profiles/Work.json", "profiles/Work 2.json",
            "profiles/Home.sync-conflict-1.json",
        ])
        #expect(
            SyncScan.conflictCopies(in: root) == [
                "gui 2.json", "init 3.lua",
                "looks.sync-conflict-20261019-120000-ABCDEFG.json",
                "palettes (Mac's conflicted copy).json",
                "profiles/Home.sync-conflict-1.json",
            ]
        )
    }

    @Test("iCloud's numbered twin of a profile is a conflict copy")
    func numberedProfileTwin() throws {
        let root = try folder([])
        let profiles = root.appendingPathComponent("profiles")
        try FileManager.default.createDirectory(
            at: profiles,
            withIntermediateDirectories: true
        )
        for (name, id) in [
            ("Work", "A"), ("Work 2", "A"), ("Home", "B"),
            ("Home 2", "C"),
        ] {
            try Data(#"{"id": "\#(id)"}"#.utf8).write(
                to: profiles.appendingPathComponent(name + ".json")
            )
        }
        #expect(SyncScan.conflictCopies(in: root) == ["profiles/Work 2.json"])
        #expect(
            SyncScan.syncedPaths(in: root) == [
                "profiles/Home 2.json", "profiles/Home.json",
                "profiles/Work.json",
            ]
        )
    }

    @Test("A file that cannot be read holds the whole scan")
    func unreadableHolds() throws {
        let root = try folder(["gui.json", "looks.json"])
        let looks = root.appendingPathComponent("looks.json")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0],
            ofItemAtPath: looks.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: looks.path
            )
        }
        #expect(SyncScan.hashes(in: root) == nil)
    }

    @Test("An iCloud placeholder is found, top level or in profiles")
    func placeholders() throws {
        let root = try folder([
            ".gui.json.icloud", "profiles/.Work.json.icloud",
            ".DS_Store",
        ])
        #expect(
            Set(SyncScan.placeholders(in: root).map(\.lastPathComponent))
                == [".gui.json.icloud", ".Work.json.icloud"]
        )
    }
}
