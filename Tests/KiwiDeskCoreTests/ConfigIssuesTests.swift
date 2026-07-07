import Foundation
import Testing

@testable import KiwiDeskCore

// The config-issues surface (#68): loadConfig publishes what it
// could not apply — a broken init.lua, an unreadable gui.json,
// invalid profile JSONs — and clears once the load is clean.

@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-issues-\(UUID().uuidString)"
            )
    )
}

@MainActor
private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try text.write(to: url, atomically: true, encoding: .utf8)
}

@Suite("Config issues surface (#68)", .serialized)
@MainActor
struct ConfigIssuesTests {
    @Test("clean load publishes no issues")
    func cleanLoad() {
        let core = makeCore()
        core.loadConfig()
        #expect(core.configIssues.isEmpty)
    }

    @Test("broken init.lua becomes an issue and clears")
    func brokenInitLua() throws {
        let core = makeCore()
        try write("this is not lua(", to: core.configURL)
        var seen: [[ConfigIssue]] = []
        core.onConfigIssuesChange = { seen.append($0) }
        core.loadConfig()
        #expect(
            core.configIssues.map(\.source) == ["init.lua"]
        )
        #expect(seen.count == 1)
        // Fixing the file clears the badge on the next load.
        try write("-- fine now", to: core.configURL)
        core.loadConfig()
        #expect(core.configIssues.isEmpty)
        #expect(seen.count == 2)
        #expect(seen.last?.isEmpty == true)
    }

    @Test("unchanged issues do not re-fire the callback")
    func noRepeatCallback() throws {
        let core = makeCore()
        try write("also not lua(", to: core.configURL)
        var fired = 0
        core.onConfigIssuesChange = { _ in fired += 1 }
        core.loadConfig()
        core.loadConfig()
        #expect(fired == 1)
    }

    @Test("invalid profile JSON becomes an issue")
    func invalidProfile() throws {
        let core = makeCore()
        try write(
            "{\"name\": \"broken\"}",
            to: core.configDirectory
                .appendingPathComponent(
                    "profiles/broken.json"
                )
        )
        core.loadConfig()
        #expect(
            core.configIssues.map(\.source)
                == ["broken.json"]
        )
    }

    @Test("unreadable gui.json becomes an issue")
    func unreadableSidecar() throws {
        let core = makeCore()
        try write(
            "not json",
            to: core.configDirectory
                .appendingPathComponent("gui.json")
        )
        core.loadConfig()
        #expect(
            core.configIssues.map(\.source) == ["gui.json"]
        )
    }
}
