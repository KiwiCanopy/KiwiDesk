import Foundation
import Testing

@testable import KiwiDeskCore

/// Compare and Copy (#2324 slice 2): a whole setup copied one way,
/// the replaced side trashed, nothing merged, and a newer folder
/// refused both ways.
@Suite("Sync folder copy (#2324)", .serialized)
@MainActor
struct SyncFolderCopyTests {
    private let files = FileManager.default

    private func folder() throws -> URL {
        let url = testTemporaryDirectory.appendingPathComponent(
            "kiwi-sync-\(UUID().uuidString)"
        )
        try files.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func guiCore() throws -> KiwiCore {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        return core
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    /// A folder another Mac filled: a setup with one profile.
    private func filledFolder(profile name: String) throws -> URL {
        let source = try guiCore()
        try source.profiles.write(profile(name))
        try write("-- theirs", to: source.configURL)
        let target = try folder()
        try source.keepThisMacsSetup(in: target) { _ in }
        return target
    }

    private func profileNames(in folder: URL) -> Set<String> {
        let names =
            (try? files.contentsOfDirectory(
                atPath: folder.appendingPathComponent("profiles").path
            )) ?? []
        return Set(names.map { ($0 as NSString).deletingPathExtension })
    }

    @Test("Keep This Mac's replaces the folder's setup and trashes it")
    func keepThisMacReplaces() throws {
        let core = try guiCore()
        try core.profiles.write(profile("Mine"))
        try write("-- mine", to: core.configURL)
        let target = try filledFolder(profile: "Theirs")
        // A store this Mac lacks must not survive in the folder.
        try write("{}", to: target.appendingPathComponent("looks.json"))
        try? files.removeItem(at: core.lookLibrary.url)
        var trashed: [String] = []
        try core.keepThisMacsSetup(in: target) { url in
            trashed.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }
        #expect(profileNames(in: target) == ["Mine"])
        #expect(
            !files.fileExists(
                atPath: target.appendingPathComponent("looks.json").path
            )
        )
        let lua = try String(
            contentsOf: target.appendingPathComponent("init.lua"),
            encoding: .utf8
        )
        #expect(lua == "-- mine")
        #expect(Set(trashed).isSuperset(of: ["profiles", "init.lua"]))
        #expect(
            files.fileExists(
                atPath: target.appendingPathComponent("gui.json").path
            )
        )
    }

    @Test("Keep the Folder's replaces this Mac's setup, keeping bindings")
    func keepFolderReplaces() throws {
        let core = try guiCore()
        var config = GuiConfig()
        config.profileBindings = [
            .number(2): DesktopBinding(profile: "Mine", desktop: 2)
        ]
        try core.guiConfigStore.saveIncludingBindings(config)
        try core.profiles.write(profile("Mine"))
        try write("-- mine", to: core.configURL)
        let source = try filledFolder(profile: "Theirs")
        var trashed: [String] = []
        try core.keepFoldersSetup(from: source) { url in
            trashed.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }
        #expect(Set(core.profiles.allProfiles().map(\.name)) == ["Theirs"])
        let lua = try String(contentsOf: core.configURL, encoding: .utf8)
        #expect(lua == "-- theirs")
        #expect(trashed.contains("init.lua"))
        #expect(
            core.guiConfigStore.bindingsFile.load()
                .profileBindings[.number(2)]?.names == ["Mine"]
        )
    }

    @Test("the comparison reads both sides and the folder's Mac")
    func comparisonReadsBothSides() throws {
        let core = try guiCore()
        try core.profiles.write(profile("Mine"))
        let target = try filledFolder(profile: "Theirs")
        let stamp = try JSONEncoder().encode(SyncStamp(mac: "Studio"))
        try stamp.write(to: target.appendingPathComponent("sync.json"))
        let comparison = core.compareSync(with: target)
        #expect(comparison.thisMac.profileCount == 1)
        #expect(comparison.folder.profileCount == 1)
        #expect(comparison.folder.mac == "Studio")
        #expect(!comparison.folder.isEmpty)
        #expect(comparison.keepThisMacRefusal == nil)
        #expect(comparison.keepFolderRefusal == nil)
    }

    @Test("an empty folder takes this Mac's and gives nothing")
    func emptyFolder() throws {
        let core = try guiCore()
        let comparison = core.compareSync(with: try folder())
        #expect(comparison.folder.isEmpty)
        #expect(comparison.keepFolderRefusal == .folderEmpty)
        #expect(comparison.keepThisMacRefusal == nil)
    }

    @Test("a newer folder refuses both ways and is left alone")
    func newerFolderRefuses() throws {
        let core = try guiCore()
        let target = try folder()
        let gui = target.appendingPathComponent("gui.json")
        try write("{\"format\": 9999}", to: gui)
        let comparison = core.compareSync(with: target)
        guard case .folderNewer? = comparison.keepThisMacRefusal,
            case .folderNewer? = comparison.keepFolderRefusal
        else {
            Issue.record("expected both directions refused")
            return
        }
        #expect(throws: SyncRefusal.self) {
            try core.keepThisMacsSetup(in: target) { _ in }
        }
        let text = try String(contentsOf: gui, encoding: .utf8)
        #expect(text == "{\"format\": 9999}")
    }

    @Test("the config folder itself is refused")
    func sameFolderRefused() throws {
        let core = try guiCore()
        #expect(
            core.syncFolderRefusal(core.configDirectory) == .sameFolder
        )
    }
}
