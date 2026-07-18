import Foundation
import Testing

@testable import KiwiDeskCore

/// The `KiwiDesk.show_shortcuts()` UI-bridge verb (#330): a Lua
/// action that raises a Core hook the GUI wires to the shortcuts
/// panel. It carries no dispatcher response, so it lives in
/// `luaOnly`, not `APIReference.commands`.
@Suite("show_shortcuts Lua verb", .serialized)
@MainActor
struct ShowShortcutsVerbTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return KiwiCore(configDirectory: dir)
    }

    @Test("KiwiDesk.show_shortcuts() fires the UI hook")
    func firesHook() throws {
        let core = makeCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        var fired = 0
        core.onShowShortcuts = { fired += 1 }
        let result = lua.run("KiwiDesk.show_shortcuts()")
        guard case .success = result else {
            Issue.record("show_shortcuts run failed: \(result)")
            return
        }
        #expect(fired == 1)
    }

    @Test("Listed as a Lua-only verb so help() covers it")
    func listedLuaOnly() {
        #expect(APIReference.luaOnly.contains("show_shortcuts"))
    }
}
