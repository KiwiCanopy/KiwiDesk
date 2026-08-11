import Foundation
import Testing

@testable import KiwiDeskCore

/// The `KiwiDesk.open_settings()` UI-bridge verb (#678 item 18):
/// the bindable "Open Settings" action, same shape as
/// `show_shortcuts` — a Lua action raising a Core hook the GUI
/// wires to the Settings window. It carries no dispatcher
/// response, so it lives in `luaOnly`, not
/// `APIReference.commands`; and it is deliberately UNBOUND by
/// default, so no `DefaultKeybindings` row may carry it.
@Suite("open_settings Lua verb", .serialized)
@MainActor
struct OpenSettingsVerbTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    @Test("KiwiDesk.open_settings() fires the UI hook")
    func firesHook() throws {
        let core = makeCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        var fired = 0
        core.uiBridge.onOpenSettings = { fired += 1 }
        let result = lua.run("KiwiDesk.open_settings()")
        guard case .success = result else {
            Issue.record("open_settings run failed: \(result)")
            return
        }
        #expect(fired == 1)
    }

    @Test("Listed as a Lua-only verb so help() covers it")
    func listedLuaOnly() {
        #expect(APIReference.luaOnly.contains("open_settings"))
    }

    @Test("Unbound by default — no seeded row carries the verb")
    func unboundByDefault() {
        let rows = DefaultKeybindings.bindings(
            spaces: ["1", "2", "3"],
            resizeStep: 40
        )
        // A negative assertion over an empty seed would pass for
        // having found nothing.
        #expect(!rows.isEmpty)
        #expect(
            !rows.contains {
                $0.lua.contains("open_settings")
            }
        )
    }
}
