import Foundation
import Testing

@testable import KiwiDeskCore

/// A Lua-owned config's Space order is the order its `init.lua`
/// first references each Space, on every load (#3625): undeclared
/// Spaces keep their relative order behind, an active profile's
/// order still wins, and a GUI-managed config keeps the sidecar's.
@Suite("Lua-owned Space order (#3625)", .serialized)
@MainActor
struct LuaSpaceOrderTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-lua-order-\(UUID().uuidString)"
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

    /// A Lua-owned `init.lua` declaring `ids` in a loop, in order.
    private func declaring(_ ids: [String]) -> String {
        let list = ids.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
            KiwiDesk.set_gap_global(10)
            for _, id in ipairs({\(list)}) do
              KiwiDesk.set_mode(id, "stack")
            end
            """
    }

    private func order(_ core: KiwiCore) -> [String] {
        core.state.workspaces.allSpaces.map(\.id.raw)
    }

    private func live(_ ids: [String], on core: KiwiCore) {
        for id in ids { core.state.workspaces.ensureSpace(SpaceID(id)) }
        core.state.workspaces.reorder(matching: ids.map { SpaceID($0) })
    }

    @Test("a load puts live C, A, B in declared A, B, C order")
    func loadImposesDeclaredOrder() throws {
        let core = makeCore()
        live(["C", "A", "B"], on: core)
        try writeInitLua(declaring(["A", "B", "C"]), core: core)
        core.loadConfig()
        #expect(order(core) == ["A", "B", "C"])
    }

    @Test("a reload with a changed declaration reorders")
    func reloadReorders() throws {
        let core = makeCore()
        try writeInitLua(declaring(["A", "B", "C"]), core: core)
        core.loadConfig()
        #expect(order(core) == ["A", "B", "C"])
        try writeInitLua(declaring(["C", "A", "B"]), core: core)
        core.loadConfig()
        #expect(order(core) == ["C", "A", "B"])
    }

    /// The order is FIRST reference, not the declaring loop's: a
    /// helper that touches a Space before the loop puts it first.
    @Test("a Space a helper touches first leads the order")
    func firstReferenceDecides() throws {
        let core = makeCore()
        try writeInitLua(
            """
            KiwiDesk.set_mode("Notes", "stack")
            """ + "\n" + declaring(["Code", "Comms", "Notes"]),
            core: core
        )
        core.loadConfig()
        #expect(order(core) == ["Notes", "Code", "Comms"])
    }

    @Test("an undeclared Space keeps its place behind the declared")
    func undeclaredStaysAtTheEnd() throws {
        let core = makeCore()
        try writeInitLua(declaring(["A", "B"]), core: core)
        core.loadConfig()
        // Command-made and named by no source: no load drops it.
        #expect(
            core.execute("create_space", args: [.string("T")])
                .isSuccess
        )
        core.state.workspaces.reorder(matching: [SpaceID("T")])
        #expect(order(core) == ["T", "A", "B"])
        try writeInitLua(declaring(["B", "A"]), core: core)
        core.loadConfig()
        #expect(order(core) == ["B", "A", "T"])
    }

    @Test("an active profile's order still wins")
    func activeProfileWins() throws {
        let core = makeCore()
        try writeInitLua(declaring(["A", "B", "C"]), core: core)
        core.loadConfig()
        core.state.workspaces.reorder(
            matching: ["C", "B", "A"].map { SpaceID($0) }
        )
        #expect(
            core.execute("save_profile", args: [.string("Work")])
                .isSuccess
        )
        #expect(core.profiles.currentName == "Work")
        core.loadConfig()
        #expect(order(core) == ["C", "B", "A"])
    }

    /// A GUI-managed config keeps the sidecar's order: the script
    /// referencing `Z` first does not move it ahead.
    @Test("a GUI-managed config keeps the sidecar's order")
    func guiManagedUnchanged() throws {
        let core = makeCore()
        var config = GuiConfig()
        config.spaces = ["A", "B"].map { SpaceID($0) }
        try core.guiConfigStore.save(config)
        try writeInitLua("KiwiDesk.create_space(\"Z\")", core: core)
        core.loadConfig()
        #expect(core.isGuiManaged)
        #expect(core.initDeclaredSpaces.contains(SpaceID("Z")))
        #expect(order(core) == ["A", "B", "Z"])
    }
}
