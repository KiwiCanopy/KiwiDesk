import Foundation
import Testing

@testable import KiwiDeskCore

/// The `KiwiDesk.open_settings()` UI-bridge verb (#678 item 18):
/// the bindable "Open Settings" action, same shape as
/// `show_shortcuts` — a Lua action raising a Core hook the GUI
/// wires to the Settings window. It carries no dispatcher
/// response, so it lives in `luaOnly`, not
/// `APIReference.commands`. Seeded on `⌃⌥,` since #1381
/// (`DefaultKeybindingsTests` ▸ `seedsOpenSettings`).
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
        // The counter is the whole discriminator, and the
        // `.success` arm above cannot stand in for it: the typo
        // guard's `__index` metamethod turns an UNREGISTERED
        // verb into a reporting no-op rather than a Lua error,
        // so dropping the registration still runs clean
        // (guard-prover, 2026-08-12).
        #expect(fired == 1)
    }

    @Test("Listed as a Lua-only verb so help() covers it")
    func listedLuaOnly() {
        #expect(APIReference.luaOnly.contains("open_settings"))
    }
}
