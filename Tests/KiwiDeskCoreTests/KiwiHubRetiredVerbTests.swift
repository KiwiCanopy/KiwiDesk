import Foundation
import Testing

@testable import KiwiDeskCore

/// The three `show_*` panel verbs retired for `kiwihub.show`
/// (#2265) with no alias: hand-written Lua and the CLI fail loudly
/// and name the new verb, since nothing rewrites a user's init.lua.
@Suite("KiwiHub retired verbs (#2265)")
@MainActor
struct KiwiHubRetiredVerbTests {
    nonisolated private static let retired = [
        "show_jump_to_window", "show_shortcuts", "show_layout_picker",
    ]

    @Test("each old verb names kiwihub.show", arguments: retired)
    func retiredNamesTheReplacement(verb: String) {
        #expect(APIReference.retired[verb] == "kiwihub.show")
        #expect(!APIReference.allCommands.contains(verb))
        let response = APIReference.helpResponse(for: verb)
        #expect(response.error?.contains("kiwihub.show") == true)
    }

    @Test("init.lua's old call is an issue naming the new verb")
    func initLuaNamesTheReplacement() throws {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwidesk-\(UUID())")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        try "KiwiDesk.show_shortcuts()".write(
            to: dir.appendingPathComponent("init.lua"),
            atomically: true,
            encoding: .utf8
        )
        let core = makeTestCore(configDirectory: dir)
        core.loadConfig()
        #expect(
            core.configIssues.map(\.kind).contains(
                .retiredCall(
                    name: "show_shortcuts",
                    replacement: "kiwihub.show"
                )
            )
        )
    }
}
