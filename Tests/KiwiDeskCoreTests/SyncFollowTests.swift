import Foundation
import Testing

@testable import KiwiDeskCore

/// Following a sync folder (#2324 slice 3), driven through the
/// pass itself: a change here goes out, a change there comes in
/// through the one door, our own copies never echo, and a pass
/// holds where either side cannot be trusted.
@Suite("A followed folder is kept in step", .serialized)
@MainActor
struct SyncFollowTests {
    private func temporary(_ name: String) -> URL {
        testTemporaryDirectory.appendingPathComponent(
            "kiwi-sync-\(name)-\(UUID().uuidString)"
        )
    }

    /// A GUI-managed core and an empty folder beside it.
    private func setup() throws -> (KiwiCore, URL) {
        let core = makeTestCore(configDirectory: temporary("config"))
        core.onLog = { _ in }
        try core.guiConfigStore.save(GuiConfig())
        let folder = temporary("folder")
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return (core, folder)
    }

    private func read(_ path: String, in root: URL) -> Data? {
        try? Data(contentsOf: root.appendingPathComponent(path))
    }

    private func write(_ text: String, to path: String, in root: URL) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url)
    }

    @Test("Following an empty folder copies this Mac's setup out")
    func emptyFolderTakesThisMac() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        #expect(read("gui.json", in: folder) != nil)
        #expect(
            read("gui.json", in: folder)
                == read("gui.json", in: core.configDirectory)
        )
        #expect(core.sync.status == .upToDate)
    }

    @Test("A change made here goes out and does not come back")
    func localChangeGoesOut() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        var ins: [SyncedChange] = []
        core.sync.onSyncedIn = { ins.append($0) }
        try write("print(1)\n", to: "init.lua", in: core.configDirectory)
        core.runSyncPass()
        #expect(read("init.lua", in: folder) == Data("print(1)\n".utf8))
        // The copy's own watch event: nothing changed either way.
        core.runSyncPass()
        #expect(ins.isEmpty)
    }

    @Test("A change in the folder comes in through the door")
    func folderChangeComesIn() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        var ins: [SyncedChange] = []
        core.sync.onSyncedIn = { ins.append($0) }
        var config = try #require(core.guiConfigStore.load())
        config.floatRules = ["app:Calculator"]
        let encoder = JSONEncoder()
        try encoder.encode(config).write(
            to: folder.appendingPathComponent("gui.json")
        )
        core.runSyncPass()
        #expect(ins.map(\.paths) == [["gui.json"]])
        #expect(
            core.guiConfigStore.load()?.floatRules == ["app:Calculator"]
        )
        core.runSyncPass()
        #expect(ins.count == 1)
    }

    @Test("A file the folder dropped leaves this Mac too")
    func folderDeletionComesIn() throws {
        let (core, folder) = try setup()
        let gone = "profiles/Gone.json"
        try write("{}", to: gone, in: core.configDirectory)
        core.followSyncFolder(folder)
        #expect(read(gone, in: folder) != nil)
        try FileManager.default.removeItem(
            at: folder.appendingPathComponent(gone)
        )
        core.runSyncPass()
        #expect(read(gone, in: core.configDirectory) == nil)
    }

    @Test("Both sides changed: nothing is copied either way")
    func bothChangedHolds() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        try write("mine", to: "init.lua", in: core.configDirectory)
        try write("theirs", to: "init.lua", in: folder)
        core.runSyncPass()
        #expect(core.sync.status == .changedOnBoth)
        #expect(read("init.lua", in: folder) == Data("theirs".utf8))
        #expect(
            read("init.lua", in: core.configDirectory) == Data("mine".utf8)
        )
    }

    @Test("A folder with another setup is not merged on follow")
    func otherSetupWaitsForCompare() throws {
        let (core, folder) = try setup()
        try write("theirs", to: "init.lua", in: folder)
        core.followSyncFolder(folder)
        #expect(core.sync.status == .changedOnBoth)
        #expect(read("init.lua", in: core.configDirectory) == nil)
    }

    @Test("After Keep the Folder's the two sides are in step")
    func keepFolderSettles() throws {
        let (core, folder) = try setup()
        let other = makeTestCore(configDirectory: temporary("other"))
        other.onLog = { _ in }
        var theirs = GuiConfig()
        theirs.spaceHistory = .allScreens
        try other.guiConfigStore.save(theirs)
        try other.profiles.write(
            Profile(
                name: "Theirs",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        try other.keepThisMacsSetup(in: folder) { _ in }
        core.followSyncFolder(folder)
        #expect(core.sync.status == .changedOnBoth)
        try core.keepFoldersSetup(from: folder) {
            try FileManager.default.removeItem(at: $0)
        }
        core.runSyncPass()
        #expect(core.sync.status == .upToDate)
        #expect(core.guiConfigStore.load()?.spaceHistory == .allScreens)
    }

    @Test("A file the folder cannot read is never read as deleted")
    func unreadableIsNotDeleted() throws {
        let (core, folder) = try setup()
        try write("x", to: "init.lua", in: core.configDirectory)
        core.followSyncFolder(folder)
        let theirs = folder.appendingPathComponent("init.lua")
        try FileManager.default.setAttributes(
            [.posixPermissions: 0],
            ofItemAtPath: theirs.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: theirs.path
            )
        }
        core.runSyncPass()
        #expect(core.sync.status == .folderUnavailable)
        #expect(read("init.lua", in: core.configDirectory) != nil)
    }

    @Test("A watch that will not start says the folder is unreachable")
    func deadWatchIsReported() throws {
        let (core, folder) = try setup()
        core.sync.watchRequired = true
        core.followSyncFolder(folder)
        #expect(core.sync.status == .folderUnavailable)
        // A later pass — after a Compare and Copy, say — keeps it.
        core.runSyncPass()
        #expect(core.sync.status == .folderUnavailable)
    }

    @Test("Reset and restore forget the agreement: no copy goes out")
    func resetForgetsTheAgreement() throws {
        let (core, folder) = try setup()
        try write("{}", to: "profiles/Keep.json", in: core.configDirectory)
        core.followSyncFolder(folder)
        #expect(read("profiles/Keep.json", in: folder) != nil)
        core.resetAllSettings { try FileManager.default.removeItem(at: $0) }
        #expect(
            !FileManager.default.fileExists(
                atPath: core.url(of: .syncLedger).path
            )
        )
        core.followSyncFolder(folder)
        #expect(core.sync.status == .changedOnBoth)
        #expect(read("profiles/Keep.json", in: folder) != nil)
    }

    @Test("A restore forgets the agreement too")
    func restoreForgetsTheAgreement() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        #expect(
            FileManager.default.fileExists(
                atPath: core.url(of: .syncLedger).path
            )
        )
        _ = try core.restoreSetup(from: core.exportSetup()) {
            try FileManager.default.removeItem(at: $0)
        }
        #expect(
            !FileManager.default.fileExists(
                atPath: core.url(of: .syncLedger).path
            )
        )
    }

    @Test("A missing folder or a placeholder holds the pass")
    func unavailableHolds() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder.appendingPathComponent("gone"))
        #expect(core.sync.status == .folderUnavailable)
        try write("", to: ".gui.json.icloud", in: folder)
        core.followSyncFolder(folder)
        #expect(core.sync.status == .folderUnavailable)
        #expect(read("gui.json", in: folder) == nil)
    }

    @Test("A newer KiwiDesk's file in the folder holds the pass")
    func newerFolderHolds() throws {
        let (core, folder) = try setup()
        try write(
            #"{"format": 999}"#,
            to: "gui.json",
            in: folder
        )
        core.followSyncFolder(folder)
        guard case .newerOnAnotherMac = core.sync.status else {
            Issue.record("expected the newer-format hold")
            return
        }
    }

    @Test("A newer KiwiDesk's file on this Mac holds the pass")
    func newerHereHolds() throws {
        let (core, folder) = try setup()
        try write(
            #"{"format": 999}"#,
            to: "gui.json",
            in: core.configDirectory
        )
        core.followSyncFolder(folder)
        guard case .newerHere = core.sync.status else {
            Issue.record("expected this Mac's newer-format hold")
            return
        }
        #expect(read("gui.json", in: folder) == nil)
    }

    @Test("A file deleted here leaves the folder too")
    func localDeletionGoesOut() throws {
        let (core, folder) = try setup()
        let gone = "profiles/Gone.json"
        try write("{}", to: gone, in: core.configDirectory)
        core.followSyncFolder(folder)
        try FileManager.default.removeItem(
            at: core.configDirectory.appendingPathComponent(gone)
        )
        core.runSyncPass()
        #expect(read(gone, in: folder) == nil)
    }

    @Test("A second change to the same file comes in too")
    func agreementAdvances() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        try write("-- one\n", to: "init.lua", in: folder)
        core.runSyncPass()
        try write("-- two\n", to: "init.lua", in: folder)
        core.runSyncPass()
        #expect(
            read("init.lua", in: core.configDirectory)
                == Data("-- two\n".utf8)
        )
        // A stale agreement would read this one-sided change as a
        // change on both sides.
        try write("-- three\n", to: "init.lua", in: core.configDirectory)
        core.runSyncPass()
        #expect(core.sync.status == .upToDate)
        #expect(read("init.lua", in: folder) == Data("-- three\n".utf8))
    }

    @Test("A conflict copy is reported, and never copied")
    func conflictCopyIsReported() throws {
        let (core, folder) = try setup()
        try write("x", to: "gui 2.json", in: folder)
        core.followSyncFolder(folder)
        #expect(core.sync.status == .conflictCopy("gui 2.json"))
        #expect(read("gui 2.json", in: core.configDirectory) == nil)
    }

    @Test("Stopping keeps both copies and the status says off")
    func stopKeepsCopies() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        core.followSyncFolder(nil)
        #expect(core.sync.status == .off)
        #expect(read("gui.json", in: folder) != nil)
        #expect(read("gui.json", in: core.configDirectory) != nil)
    }

    @Test("No pass runs while a Compare and Copy rewrites a side")
    func pauseHoldsThePass() throws {
        let (core, folder) = try setup()
        core.followSyncFolder(folder)
        try write("half", to: "init.lua", in: core.configDirectory)
        core.pausingSync { core.runSyncPass() }
        #expect(read("init.lua", in: folder) == nil)
    }
}
