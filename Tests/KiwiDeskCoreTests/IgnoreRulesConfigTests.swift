import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Ignore-rule config", .serialized)
@MainActor
struct IgnoreRulesConfigTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-ignore-\(UUID().uuidString)"
                )
        )
    }

    private func write(
        _ source: String,
        to core: KiwiCore
    ) throws {
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try source.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("Lua table populates the global matcher")
    func luaTableLoads() throws {
        let core = makeCore()
        try write(
            "ignore_rules = { \"io.tailscale.ipn.macos\" }",
            to: core
        )

        core.loadConfig()

        #expect(
            core.eventLoop.ignoreRules.rawRules
                == ["io.tailscale.ipn.macos"]
        )
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "IO.TAILSCALE.IPN.MACOS"
            )
        )
    }

    @Test("Removing table clears live matcher")
    func reloadIsAuthoritative() throws {
        let core = makeCore()
        try write(
            "ignore_rules = { \"io.tailscale.ipn.macos\" }",
            to: core
        )
        core.loadConfig()
        #expect(
            core.eventLoop.ignoreRules.matches(
                bundleID: "io.tailscale.ipn.macos"
            )
        )

        try write("", to: core)
        core.loadConfig()

        #expect(
            !core.eventLoop.ignoreRules.matches(
                bundleID: "io.tailscale.ipn.macos"
            )
        )
    }
}
