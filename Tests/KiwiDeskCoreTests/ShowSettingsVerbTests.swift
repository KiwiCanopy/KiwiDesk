import Foundation
import Testing

@testable import KiwiDeskCore

/// The `KiwiDesk.show_settings()` UI-bridge verb (#678 item 18):
/// the bindable "Open Settings" action, same shape as
/// `show_shortcuts` — a Lua action raising a Core hook the GUI
/// wires to the Settings window. It carries no dispatcher
/// response, so it lives in `luaOnly`, not
/// `APIReference.commands`; and it is deliberately UNBOUND by
/// default, so no `DefaultKeybindings` row may carry it.
@Suite("show_settings Lua verb", .serialized)
@MainActor
struct ShowSettingsVerbTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    @Test("KiwiDesk.show_settings() fires the UI hook")
    func firesHook() throws {
        let core = makeCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        var fired = 0
        core.uiBridge.onShowSettings = { fired += 1 }
        let result = lua.run("KiwiDesk.show_settings()")
        guard case .success = result else {
            Issue.record("show_settings run failed: \(result)")
            return
        }
        #expect(fired == 1)
    }

    @Test("Listed as a Lua-only verb so help() covers it")
    func listedLuaOnly() {
        #expect(APIReference.luaOnly.contains("show_settings"))
    }

    @Test("Unbound by default — no seeded row carries the verb")
    func unboundByDefault() {
        let rows = DefaultKeybindings.bindings(
            spaces: ["1", "2", "3"],
            resizeStep: 40
        )
        #expect(
            !rows.contains {
                $0.lua.contains("show_settings")
            }
        )
    }
}
