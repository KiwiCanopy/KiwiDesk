import Foundation
import Testing

@testable import KiwiDeskCore

/// `pull_or_spawn` retired for `focus_or_spawn` (#1511) with no
/// alias: hand-written Lua and the CLI fail loudly and name the
/// new verb, since nothing rewrites a user's init.lua.
@Suite("Focus or spawn retired verb (#1511)")
@MainActor
struct FocusOrSpawnRetiredVerbTests {
    @Test("the CLI refuses the old verb and names the new one")
    func cliNamesTheReplacement() {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwidesk-\(UUID())")
        )
        let response = core.execute(
            "pull_or_spawn",
            args: [.string("com.test.a")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("focus_or_spawn") == true)
        #expect(!APIReference.dispatchable.contains("pull_or_spawn"))
        #expect(APIReference.dispatchable.contains("focus_or_spawn"))
    }

    @Test("init.lua's old call is an issue naming the new verb")
    func initLuaNamesTheReplacement() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwidesk-\(UUID())")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try "KiwiDesk.pull_or_spawn(\"com.test.a\")".write(
            to: dir.appendingPathComponent("init.lua"),
            atomically: true,
            encoding: .utf8
        )
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        #expect(
            core.configIssues.map(\.kind).contains(
                .retiredCall(
                    name: "pull_or_spawn",
                    replacement: "focus_or_spawn"
                )
            )
        )
    }

    @Test("help on the old verb names the new one")
    func helpNamesTheReplacement() {
        let response = APIReference.helpResponse(for: "pull_or_spawn")
        #expect(!response.isSuccess)
        #expect(response.error?.contains("focus_or_spawn") == true)
    }
}
