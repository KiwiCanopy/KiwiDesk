import Foundation
import Testing

@testable import KiwiDeskCore

// The namespace typo guard (#39): an unknown call on KiwiDesk
// or a layout namespace table logs a did-you-mean and keeps
// the rest of init.lua running; during a config load the hit
// also surfaces as a ConfigIssue so it cannot go unnoticed.

@MainActor
private func makeCore(config: String? = nil) -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwi-typo-\(UUID().uuidString)"
        )
    let core = KiwiCore(configDirectory: directory)
    if let config {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try? config.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }
    return core
}

@Suite("Namespace typo guard (#39)", .serialized)
@MainActor
struct TypoGuardTests {
    @Test("A namespace typo logs and the config keeps running")
    func nonFatal() {
        let core = makeCore(
            config: """
                scroll.set_width(1550)
                marker = 42
                """
        )
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.loadConfig()
        #expect(core.lua?.global("marker") == .number(42))
        #expect(
            logs.contains {
                $0.contains("set_width")
                    && $0.contains("KiwiDesk.help()")
            }
        )
    }

    @Test("A load-time namespace typo becomes a ConfigIssue")
    func loadIssue() {
        let core = makeCore(config: "scroll.set_width(1)")
        core.loadConfig()
        #expect(
            core.configIssues.contains {
                $0.source == "init.lua"
                    && $0.message.contains(
                        "scroll.set_width"
                    )
            }
        )
    }

    @Test("A top-level typo during load is an issue too")
    func topLevelLoadIssue() {
        let core = makeCore(
            config: """
                KiwiDesk.focsu("left")
                marker = 1
                """
        )
        core.loadConfig()
        #expect(core.lua?.global("marker") == .number(1))
        #expect(
            core.configIssues.contains {
                $0.message.contains("focsu")
                    && $0.message.contains("focus")
            }
        )
    }

    @Test("One typo in a loop dedupes to a single issue")
    func dedupe() {
        let core = makeCore(
            config: """
                for i = 1, 3 do
                    scroll.set_width(i)
                end
                """
        )
        core.loadConfig()
        #expect(core.configIssues.count == 1)
    }

    @Test("A runtime typo logs but records no ConfigIssue")
    func runtimeHitOnlyLogs() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.loadConfig()
        #expect(core.configIssues.isEmpty)
        let result = core.lua?.run("scroll.set_width(1)")
        let succeeded: Bool =
            if case .success = result { true } else { false }
        #expect(succeeded)
        #expect(logs.contains { $0.contains("set_width") })
        #expect(core.configIssues.isEmpty)
    }

    @Test("A reload clears a fixed typo's issue")
    func issueClearsOnReload() throws {
        let core = makeCore(config: "scroll.set_width(1)")
        core.loadConfig()
        #expect(!core.configIssues.isEmpty)
        try "scroll.set_slot_size(1550)".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.configIssues.isEmpty)
    }

    @Test("Every namespace table is guarded")
    func allNamespacesGuarded() {
        // One typo per namespace: proves the install chunk
        // compiled and every table got its guard — a broken
        // install would abort at the first call instead.
        let tables = APIReference.namespaces.keys.sorted()
        let core = makeCore(
            config:
                tables
                .map { "\($0).no_such_fn_xyz(1)" }
                .joined(separator: "\n")
        )
        core.loadConfig()
        for table in tables {
            #expect(
                core.configIssues.contains {
                    $0.message.contains(
                        "\(table).no_such_fn_xyz"
                    )
                },
                "unguarded namespace: \(table)"
            )
        }
    }

    @Test("Namespaced typos get a did-you-mean suggestion")
    func namespacedSuggestion() {
        #expect(
            APIReference.suggestion(
                for: "scroll.set_slot_sze"
            ) == "scroll.set_slot_size"
        )
        #expect(
            APIReference.suggestion(
                for: "stack.set_master_ratoi"
            ) == "stack.set_master_ratio"
        )
    }
}
