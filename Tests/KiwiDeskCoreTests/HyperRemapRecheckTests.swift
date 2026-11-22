import Foundation
import Testing

@testable import KiwiDeskCore

/// A stateful `hidutil` and record another tool can rewrite
/// underneath, as Hyperkey does (#3550).
@MainActor
private final class Host {
    var mapping: Set<HyperKeyRemap.Pair> = []
    var written: HyperKeyRemap.Pair?
    var gets = 0
    var sets = 0

    var host: HyperKeyRemap.Host {
        HyperKeyRemap.Host(
            run: { arguments in
                if arguments.contains("--get") {
                    self.gets += 1
                    return self.listing
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

    private var listing: String {
        mapping.map {
            "1 UserKeyMapping (\n{\n"
                + "HIDKeyboardModifierMappingSrc = \($0.source);\n"
                + "HIDKeyboardModifierMappingDst = \($0.destination);\n"
                + "}\n)"
        }.joined(separator: "\n")
    }
}

@MainActor
private final class Log {
    var lines: [String] = []
    func count(_ needle: String) -> Int {
        lines.count { $0.contains(needle) }
    }
}

private let ours = HyperKeyRemap.pair(for: .capsLock)
/// What Hyperkey writes at launch: Caps Lock → Left Command.
private let capsToCommand = HyperKeyRemap.Pair(
    source: HyperKeyRemap.usage(0x39),
    destination: HyperKeyRemap.usage(0xE3)
)
/// What Hyperkey leaves at quit.
private let identity = HyperKeyRemap.Pair(
    source: HyperKeyRemap.usage(0x39),
    destination: HyperKeyRemap.usage(0x39)
)

/// The Hyper remap's re-check (#3550): `recheckHyperKey`, a
/// Settings Save and a wake re-read a mapping another tool may
/// have changed, through the coalesced `.hyperRemap` slot — a
/// vanished entry is set again, another tool's is refused, and a
/// layer activation or a reload re-checks nothing.
@MainActor
@Suite("Hyper remap re-check", .serialized)
struct HyperRemapRecheckTests {
    /// A running core with Caps Lock applied, its gui.json storing
    /// the key, so a reload keeps it.
    private func applied() async throws -> (KiwiCore, Host, Log) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("recheck-\(UUID().uuidString)")
        )
        core.deferred.sleep = { _ in }
        try core.guiConfigStore.save(GuiConfig())
        let host = Host()
        let log = Log()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        core.setAppWide(persisting: true) { $0.hyperKey = .capsLock }
        await core.deferred.task(for: .hyperRemap)?.value
        core.onLog = { log.lines.append($0) }
        #expect(core.keys.hyperStatus == .on)
        #expect(host.written == ours)
        return (core, host, log)
    }

    /// Owed, never run inline: nothing is read until the slot runs.
    private func settle(_ core: KiwiCore, _ host: Host) async {
        let gets = host.gets
        #expect(core.deferred.isScheduled(.hyperRemap))
        #expect(host.gets == gets)
        await core.deferred.task(for: .hyperRemap)?.value
    }

    @Test("a re-check re-applies a cleared mapping")
    func recheckHeals() async throws {
        let (core, host, _) = try await applied()
        host.mapping = []
        core.recheckHyperKey()
        await settle(core, host)
        #expect(host.mapping == [ours])
        #expect(host.written == ours)
        #expect(core.keys.hyperStatus == .on)
    }

    @Test("a Settings Save re-applies a cleared mapping")
    func saveHeals() async throws {
        let (core, host, _) = try await applied()
        host.mapping = []
        let config = try #require(core.guiConfigStore.load())
        try core.saveGuiConfig(config)
        await settle(core, host)
        #expect(host.mapping == [ours])
        #expect(core.keys.hyperStatus == .on)
    }

    @Test("a wake or an unlock re-applies a cleared mapping")
    func returnHeals() async throws {
        let (core, host, _) = try await applied()
        host.mapping = []
        core.sleepWake.onReturn()
        await settle(core, host)
        #expect(host.mapping == [ours])
        #expect(core.keys.hyperStatus == .on)
    }

    @Test("another tool's entry over ours is refused, the record dropped")
    func foreignEntryRefuses() async throws {
        let (core, host, _) = try await applied()
        var pushes = 0
        core.onAppWideChange = { pushes += 1 }
        host.mapping = [capsToCommand]
        core.recheckHyperKey()
        await core.deferred.task(for: .hyperRemap)?.value
        guard case .refused = core.keys.hyperStatus else {
            Issue.record("\(core.keys.hyperStatus)")
            return
        }
        #expect(!core.keys.hyperEnabled)
        #expect(host.written == nil)
        #expect(pushes == 1)
        let sets = host.sets
        core.retireHyperKey()
        #expect(host.sets == sets)
        #expect(host.mapping == [capsToCommand])
    }

    @Test("an identity entry left at quit is replaced by ours")
    func identityIsReplaced() async throws {
        let (core, host, _) = try await applied()
        host.mapping = [identity]
        core.recheckHyperKey()
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.mapping == [ours])
        #expect(core.keys.hyperStatus == .on)
    }

    @Test("our entry intact: one listing, no write")
    func intactReadsOnce() async throws {
        let (core, host, log) = try await applied()
        let (gets, sets) = (host.gets, host.sets)
        core.recheckHyperKey()
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.gets == gets + 1)
        #expect(host.sets == sets)
        #expect(log.lines.isEmpty)
    }

    @Test("no key and no record spawns nothing")
    func offSpawnsNothing() async {
        let core = makeTestCore()
        core.deferred.sleep = { _ in }
        let host = Host()
        core.hyperRemapHost = host.host
        core.eventLoop.isRunning = true
        core.recheckHyperKey()
        core.sleepWake.onReturn()
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.gets + host.sets == 0)
        #expect(core.keys.hyperStatus == .off)
    }

    @Test("repeated re-checks while refused log once")
    func refusalLogsOnce() async throws {
        let (core, host, log) = try await applied()
        host.mapping = [capsToCommand]
        for _ in 0..<3 {
            core.recheckHyperKey()
            await core.deferred.task(for: .hyperRemap)?.value
        }
        #expect(log.count("remap refused") == 1)
    }

    @Test("a layer activation or a gui.json reload re-checks nothing")
    func activationAndReloadAreQuiet() async throws {
        let (core, host, _) = try await applied()
        let settled = core.deferred.task(for: .hyperRemap)
        let gets = host.gets
        core.keys.activate(core.keys.currentLayer)
        core.loadConfig()
        #expect(core.deferred.task(for: .hyperRemap) == settled)
        #expect(host.gets == gets)
    }

    @Test("a re-check and a Save in one turn read once")
    func recheckAndSaveCoalesce() async throws {
        let (core, host, _) = try await applied()
        host.mapping = []
        let gets = host.gets
        core.recheckHyperKey()
        let config = try #require(core.guiConfigStore.load())
        try core.saveGuiConfig(config)
        await core.deferred.task(for: .hyperRemap)?.value
        #expect(host.gets == gets + 1)
        #expect(host.mapping == [ours])
    }

    @Test("a paused core re-checks nothing")
    func pausedSpawnsNothing() {
        let core = makeTestCore()
        let host = Host()
        core.hyperRemapHost = host.host
        core.setAppWide(persisting: false) { $0.hyperKey = .capsLock }
        core.recheckHyperKey()
        core.sleepWake.onReturn()
        #expect(core.deferred.task(for: .hyperRemap) == nil)
        #expect(host.gets + host.sets == 0)
    }
}
