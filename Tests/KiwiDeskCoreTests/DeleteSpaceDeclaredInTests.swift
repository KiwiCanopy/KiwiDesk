import Foundation
import Testing

@testable import KiwiDeskCore

/// `delete_space` names every source that re-creates the Space
/// on the next config load (#1509): the active profile from
/// adoption state, the last `init.lua` run's asks, and a
/// GUI-managed sidecar's list. A runtime-only Space carries no
/// payload at all, so today's scripts see byte-identical output.
@Suite("delete_space names its re-creators (#1509)", .serialized)
@MainActor
struct DeleteSpaceDeclaredInTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-declared-\(UUID().uuidString)"
                )
        )
    }

    private func writeInitLua(_ body: String, core: KiwiCore) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try body.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// The `declared_in` array of a delete, nil when the response
    /// carried no data.
    private func declaredIn(
        deleting space: String,
        on core: KiwiCore
    ) -> [String]? {
        let r = core.execute("delete_space", args: [.string(space)])
        #expect(r.isSuccess)
        guard case .object(let fields)? = r.data,
            case .array(let sources)? = fields["declared_in"]
        else { return nil }
        return sources.compactMap(\.stringValue)
    }

    @Test("a runtime-only Space produces no data at all")
    func runtimeOnlyIsSilent() {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        let r = core.execute("delete_space", args: [.string("2")])
        #expect(r.isSuccess)
        #expect(r.data == nil)
    }

    @Test("a Space the active profile declares names that profile")
    func profileIsNamedFromAdoptionState() throws {
        let core = makeCore()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        #expect(
            core.execute("save_profile", args: [.string("Work")])
                .isSuccess
        )
        // Adoption state, never the file (#1245): the answer
        // survives the profile's deletion from disk.
        try FileManager.default.removeItem(
            at: core.profiles.fileURL(name: "Work")
        )
        #expect(
            declaredIn(deleting: "2", on: core) == ["profile:Work"]
        )
    }

    @Test("a Space init.lua creates names the script")
    func initLuaIsNamed() throws {
        let core = makeCore()
        // A `set_*` verb keeps the config Lua-owned, so no sidecar
        // is seeded and the script is the only re-creator.
        try writeInitLua(
            """
            KiwiDesk.set_gap_global(10)
            KiwiDesk.create_space("scratch")
            """,
            core: core
        )
        core.loadConfig()
        #expect(core.state.workspaces[SpaceID("scratch")] != nil)
        #expect(declaredIn(deleting: "scratch", on: core) == ["init.lua"])
    }

    /// The case a before/after diff of the space set misses: on a
    /// reload the Space already exists and `create_space` changes
    /// nothing, yet the script still brings it back.
    @Test("a reload of an existing Space still names init.lua")
    func reloadOfExistingSpaceIsNamed() throws {
        let core = makeCore()
        try writeInitLua(
            """
            KiwiDesk.set_gap_global(10)
            KiwiDesk.create_space("scratch")
            """,
            core: core
        )
        core.state.workspaces.ensureSpace(SpaceID("scratch"))
        core.loadConfig()
        #expect(declaredIn(deleting: "scratch", on: core) == ["init.lua"])
    }

    @Test("the ledger is the last run's, not the session's")
    func ledgerIsRunScoped() throws {
        let core = makeCore()
        try writeInitLua(
            """
            KiwiDesk.set_gap_global(10)
            KiwiDesk.create_space("old")
            """,
            core: core
        )
        core.loadConfig()
        // The script no longer asks for `old`; a Space created
        // after the run is not the script's either.
        try writeInitLua("KiwiDesk.set_gap_global(10)", core: core)
        core.loadConfig()
        core.state.workspaces.ensureSpace(SpaceID("later"))
        #expect(declaredIn(deleting: "old", on: core) == nil)
        #expect(declaredIn(deleting: "later", on: core) == nil)
    }

    @Test("a Space a GUI-managed sidecar lists names gui.json")
    func guiSidecarIsNamed() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        try core.guiConfigStore.save(config)
        #expect(core.isGuiManaged)
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("2"))
        #expect(declaredIn(deleting: "2", on: core) == ["gui.json"])
    }

    @Test("every re-creator is named in one array")
    func allThreeAtOnce() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("scratch")]
        try core.guiConfigStore.save(config)
        try writeInitLua(
            "KiwiDesk.create_space(\"scratch\")",
            core: core
        )
        core.loadConfig()
        #expect(
            core.execute("save_profile", args: [.string("Work")])
                .isSuccess
        )
        #expect(
            declaredIn(deleting: "scratch", on: core)
                == ["profile:Work", "init.lua", "gui.json"]
        )
    }

    /// The mechanism under the reload clause: the primitive records
    /// an id it already holds, so no creation route bypasses it.
    @Test("ensureSpace records an id it already holds")
    func primitiveRecordsExistingIds() {
        var workspaces = WorkspaceManager()
        workspaces.ensureSpace(SpaceID("a"))
        workspaces.referenced = []
        workspaces.ensureSpace(SpaceID("a"))
        #expect(workspaces.referenced == [SpaceID("a")])
    }
}
