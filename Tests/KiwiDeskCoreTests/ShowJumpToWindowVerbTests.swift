import Foundation
import Testing

@testable import KiwiDeskCore

/// The `KiwiDesk.show_jump_to_window()` UI-bridge verb (#1875): a Lua
/// action that raises a Core hook the GUI wires to the Jump to
/// window panel. It carries no dispatcher response, so it lives in
/// `luaOnly`, not `APIReference.commands`.
@Suite("show_jump_to_window Lua verb", .serialized)
@MainActor
struct ShowJumpToWindowVerbTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    @Test("KiwiDesk.show_jump_to_window() fires the UI hook")
    func firesHook() throws {
        let core = makeCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        var fired = 0
        core.uiBridge.onShowJumpToWindow = { fired += 1 }
        let result = lua.run("KiwiDesk.show_jump_to_window()")
        guard case .success = result else {
            Issue.record("show_jump_to_window run failed: \(result)")
            return
        }
        #expect(fired == 1)
    }

    @Test("Listed as a Lua-only verb so help() covers it")
    func listedLuaOnly() {
        #expect(APIReference.luaOnly.contains("show_jump_to_window"))
    }
}
