import Foundation
import Testing

@testable import KiwiDeskCore

/// A Lua-owned config's `init.lua` is the store for the Hyper key
/// (#1870): a reload whose file no longer calls `set_hyper_key`
/// gives the key back, as a relaunch would, and one that still
/// calls it remaps nothing in between.
@MainActor
@Suite("Hyper key Lua reload", .serialized)
struct HyperKeyLuaReloadTests {
    private final class Host {
        var mapping: Set<HyperKeyRemap.Pair> = []
        var written: HyperKeyRemap.Pair?
        var sets = 0

        var host: HyperKeyRemap.Host {
            HyperKeyRemap.Host(
                run: { arguments in
                    if arguments.contains("--get") {
                        return self.mapping.map {
                            "1 UserKeyMapping (\n{\n"
                                + "HIDKeyboardModifierMappingSrc = "
                                + "\($0.source);\n"
                                + "HIDKeyboardModifierMappingDst = "
                                + "\($0.destination);\n}\n)"
                        }.joined(separator: "\n")
                    }
                    self.sets += 1
                    let json = arguments.last ?? ""
                    self.mapping =
                        json.contains("Src")
                        ? [HyperKeyRemap.pair(for: .capsLock)] : []
                    return ""
                },
                readWritten: { self.written },
                writeWritten: { self.written = $0 }
            )
        }
    }

    private func core(_ lua: String) throws -> (KiwiCore, Host) {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent("hyper-lua-\(UUID().uuidString)")
        let core = makeTestCore(configDirectory: directory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        let host = Host()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        return (core, host)
    }

    @Test("a reload without the verb gives the key back")
    func droppedVerbGivesTheKeyBack() async throws {
        let managed = "KiwiDesk.set_gap_global(4)\n"
        let (core, host) = try core(
            managed + "KiwiDesk.set_hyper_key(\"caps_lock\")\n"
        )
        core.loadConfig()
        #expect(!core.isGuiManaged)
        #expect(core.appWide.hyperKey == .capsLock)
        #expect(!host.mapping.isEmpty)
        try managed.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(core.appWide.hyperKey == nil)
        #expect(host.mapping.isEmpty)
    }

    @Test("a reload that keeps the verb remaps nothing in between")
    func keptVerbStaysPut() async throws {
        let (core, host) = try core(
            "KiwiDesk.set_gap_global(4)\n"
                + "KiwiDesk.set_hyper_key(\"caps_lock\")\n"
        )
        core.loadConfig()
        let setsAfterFirst = host.sets
        core.loadConfig()
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.sets == setsAfterFirst)  // no off, no re-set
        #expect(!host.mapping.isEmpty)
    }

    @Test("a stop gives back what was applied, an off still owed")
    func stopReadsTheRecord() {
        let core = makeTestCore()
        let host = Host()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        core.applyHyperKey()
        #expect(!host.mapping.isEmpty)
        // Off is owed, not run, when the stop arrives.
        core.setAppWide(persisting: false) { $0.hyperKey = nil }
        core.retireHyperKey()
        #expect(host.mapping.isEmpty)
    }
}
