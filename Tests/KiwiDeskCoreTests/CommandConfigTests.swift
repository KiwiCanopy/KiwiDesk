import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@Suite("Config loading", .serialized)
@MainActor
struct ConfigTests {
    @Test("init.lua drives settings, rules, and events")
    func endToEnd() throws {
        let core = makeCore()
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let config = """
            KiwiDesk.set_gap_global(16)
            stack.set_master_count(3)
            float_rules = { "Calculator" }
            app_rules = { ["spotify"] = "music" }
            KiwiDesk.on("layout_change", function(id, mode)
                last_mode = mode
            end)
            """
        try config.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()

        #expect(
            core.tiler.settings.gapsGlobal == .uniform(16)
        )
        #expect(core.tiler.settings.stack.masterCount == 3)
        #expect(
            core.state.appRules["spotify"]
                == SpaceID("music")
        )

        // Trigger a layout change; the Lua callback runs.
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        #expect(
            core.lua?.global("last_mode")
                == .string("monocle")
        )
    }

    @Test("Missing config is created with defaults")
    func defaultConfig() {
        let core = makeCore()
        core.loadConfig()
        #expect(
            FileManager.default.fileExists(
                atPath: core.configURL.path
            )
        )
    }

    @Test("Lua typos log a hint instead of erroring")
    func typoGuard() throws {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.loadConfig()
        let result = core.lua?.run(
            "KiwiDesk.focsu('left')"
        )
        #expect(result?.succeeded == true)
        #expect(
            logs.contains {
                $0.contains("focsu")
                    && $0.contains("KiwiDesk.help()")
            }
        )
    }
}

@Suite("API reference")
struct APIReferenceTests {
    @Test("Suggestions catch close typos only")
    func suggestions() {
        #expect(
            APIReference.suggestion(for: "set_mdoe")
                == "set_mode"
        )
        #expect(
            APIReference.suggestion(for: "focsu") == "focus"
        )
        #expect(
            APIReference.suggestion(
                for: "completely_unrelated_xyz"
            ) == nil
        )
    }

    @Test("Edit distance is symmetric and exact")
    func editDistance() {
        #expect(APIReference.editDistance("", "abc") == 3)
        #expect(
            APIReference.editDistance("focus", "focus") == 0
        )
        #expect(
            APIReference.editDistance("focus", "focsu") == 2
        )
    }
}

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}
