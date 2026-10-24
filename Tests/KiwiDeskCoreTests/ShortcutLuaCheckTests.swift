import Foundation
import Testing

@testable import KiwiDeskCore

/// Settings asks Core whether a row's Lua compiles when the edit is
/// committed (#2574). The check compiles and never runs: a body
/// that escapes the binding's wrapper executes code under
/// `makeFunction`, and must not at edit time.
@Suite("Core's Lua check compiles and runs nothing (#2574)")
@MainActor
struct ShortcutLuaCheckTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-lcheck-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "".write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    @Test("A body that compiles has no problem; one that does not has")
    func verdicts() throws {
        let core = try core()
        #expect(core.shortcutLuaProblem("KiwiDesk.focus(\"left\")") == nil)
        #expect(core.shortcutLuaProblem("") == nil)
        let problem = try #require(core.shortcutLuaProblem("test "))
        #expect(problem.contains("syntax error"))
    }

    /// The control: `makeFunction` runs an escaping body, so the
    /// fixture would set the global if the check ran it.
    @Test("An escaping body is compiled, not run")
    func escapeRunsNothing() throws {
        let core = try core()
        let lua = try #require(core.keys.lua)
        let escape = "end, (function() kiwi_escaped = true end)(), function()"
        #expect(core.shortcutLuaProblem(escape) == nil)
        #expect(lua.global("kiwi_escaped") == .none)
        if case .success(let ref) = lua.makeFunction(body: escape) {
            lua.release(ref: ref)
        }
        #expect(lua.global("kiwi_escaped") == .bool(true))
    }
}
