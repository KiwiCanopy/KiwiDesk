import Foundation
import Testing

@testable import KiwiDeskCore

/// Keep the Folder's edges (#2324 slice 2): ownership judged on the
/// incoming files, nothing merged, nothing taken half, this Mac's
/// bindings untouched and the folder never written.
@Suite("Sync folder take (#2324)", .serialized)
@MainActor
struct SyncFolderTakeTests {
    private let files = FileManager.default
    private let foreign = "KiwiDesk.bind(\"alt\", \"x\", function() end)"

    private func folder() throws -> URL {
        let url = testTemporaryDirectory.appendingPathComponent(
            "kiwi-sync-take-\(UUID().uuidString)"
        )
        try files.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
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

    /// A folder another Mac filled, with `lua` as its init.lua.
    private func filled(lua: String, gui: Bool = true) throws -> URL {
        let source = try guiCore()
        try source.profiles.write(profile("Theirs"))
        try write(lua, to: source.configURL)
        let target = try folder()
        try source.keepThisMacsSetup(in: target) { _ in }
        if !gui {
            try files.removeItem(
                at: target.appendingPathComponent("gui.json")
            )
        }
        return target
    }

    private func remove(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    @Test("a Lua-owned Mac takes a GUI-managed folder")
    func luaOwnedMacTakesGuiFolder() throws {
        let core = try guiCore()
        try write(foreign, to: core.configURL)
        #expect(!core.isGuiManaged)
        let source = try filled(lua: "-- theirs")
        #expect(core.keepFolderRefusal(source) == nil)
        try core.keepFoldersSetup(from: source, trash: remove)
        #expect(core.isGuiManaged)
    }

    @Test("a Lua-owned folder lands whole on a GUI-managed Mac")
    func luaOwnedFolderLandsWhole() throws {
        let core = try guiCore()
        let source = try filled(lua: foreign)
        // The folder's gui.json declares a Space its init.lua owns
        // over; the take must not push it live beside the Lua setup.
        let gui = GuiConfigStore(
            directory: source,
            machine: source.appendingPathComponent("machine")
        )
        var config = try #require(gui.load())
        config.spaces.append(SpaceID("sidecar-only"))
        config.spaceModes[SpaceID("sidecar-only")] = .monocle
        try gui.save(config)
        try core.keepFoldersSetup(from: source, trash: remove)
        let live = core.state.workspaces.allSpaces.map(\.id)
        #expect(!live.contains(SpaceID("sidecar-only")))
        let lua = try String(contentsOf: core.configURL, encoding: .utf8)
        #expect(lua == foreign)
        #expect(!core.isGuiManaged)
    }

    @Test("a folder with profiles and no settings is refused")
    func noSettingsRefused() throws {
        let core = try guiCore()
        let source = try filled(lua: "-- theirs", gui: false)
        #expect(core.keepFolderRefusal(source) == .folderUnreadable)
        #expect(throws: SyncRefusal.folderUnreadable) {
            try core.keepFoldersSetup(from: source, trash: remove)
        }
    }

    @Test("a folder whose own init.lua owns it replaces gui.json too")
    func luaOnlyFolderReplacesGui() throws {
        let core = try guiCore()
        let source = try filled(lua: foreign, gui: false)
        try core.keepFoldersSetup(from: source, trash: remove)
        #expect(!core.guiConfigStore.exists)
    }

    @Test("a profile that will not decode refuses the take")
    func brokenProfileRefuses() throws {
        let core = try guiCore()
        try core.profiles.write(profile("Mine"))
        let source = try filled(lua: "-- theirs")
        try write(
            "{ not json",
            to: source.appendingPathComponent("profiles/Broken.json")
        )
        #expect(core.keepFolderRefusal(source) == .folderUnreadable)
        #expect(throws: SyncRefusal.self) {
            try core.keepFoldersSetup(from: source, trash: remove)
        }
        #expect(core.profiles.allProfiles().map(\.name) == ["Mine"])
    }

    @Test("the take leaves this Mac's bindings file alone")
    func bindingsUntouched() throws {
        let core = try guiCore()
        var config = GuiConfig()
        config.profileBindings = [
            .number(2): DesktopBinding(profile: "Mine", desktop: 2)
        ]
        try core.guiConfigStore.saveIncludingBindings(config)
        let source = try filled(lua: "-- theirs")
        var trashed: [String] = []
        try core.keepFoldersSetup(from: source) { url in
            trashed.append(url.lastPathComponent)
            try FileManager.default.removeItem(at: url)
        }
        #expect(!trashed.contains("bindings.json"))
        #expect(
            core.guiConfigStore.bindingsFile.load()
                .profileBindings[.number(2)]?.names == ["Mine"]
        )
    }

    @Test("reading an older folder migrates the copy, never the folder")
    func olderFolderStaysAsWritten() throws {
        let core = try guiCore()
        let source = try filled(lua: "-- theirs")
        let file = source.appendingPathComponent("profiles/Theirs.json")
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file))
                as? [String: Any]
        )
        root["format"] = Profile.currentFormat - 1
        let older = try JSONSerialization.data(withJSONObject: root)
        try older.write(to: file)
        try core.keepFoldersSetup(from: source, trash: remove)
        #expect(try Data(contentsOf: file) == older)
    }

    @Test("a folder inside the config folder, or holding it, is refused")
    func nestedFoldersRefused() throws {
        let core = try guiCore()
        let inside = core.configDirectory.appendingPathComponent("sub")
        try files.createDirectory(
            at: inside,
            withIntermediateDirectories: true
        )
        #expect(core.syncFolderRefusal(inside) == .sameFolder)
        let parent = core.configDirectory.deletingLastPathComponent()
        #expect(core.syncFolderRefusal(parent) == .sameFolder)
    }

    @Test("a copy that cannot stage leaves the folder as it was")
    func failedStageLeavesTheFolder() throws {
        let core = try guiCore()
        try core.profiles.write(profile("Mine"))
        let target = try filled(lua: "-- theirs")
        let mine = try core.profiles.fileURL(name: "Mine")
        try files.setAttributes(
            [.posixPermissions: 0o000],
            ofItemAtPath: mine.path
        )
        defer {
            try? files.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: mine.path
            )
        }
        #expect(throws: SyncRefusal.self) {
            try core.keepThisMacsSetup(in: target, trash: remove)
        }
        let names = try files.contentsOfDirectory(
            atPath: target.appendingPathComponent("profiles").path
        )
        #expect(names == ["Theirs.json"])
    }

    @Test("a take whose write fails still lands init.lua and reloads")
    func failedWriteStillLandsInitLua() throws {
        let core = try guiCore()
        try write("-- mine", to: core.configURL)
        let source = try filled(lua: "-- theirs")
        let file = source.appendingPathComponent("profiles/Theirs.json")
        var root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file))
                as? [String: Any]
        )
        root["name"] = "../Escapes"
        try JSONSerialization.data(withJSONObject: root).write(to: file)
        #expect(throws: SyncRefusal.self) {
            try core.keepFoldersSetup(from: source, trash: remove)
        }
        let lua = try String(contentsOf: core.configURL, encoding: .utf8)
        #expect(lua == "-- theirs")
    }
}
