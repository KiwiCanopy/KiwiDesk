import Foundation
import Testing

@testable import KiwiDeskCore

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}

/// In-flight dedup + default-timeout behavior for `KiwiDesk.exec`
/// (#467). Kept separate from `ExecTests` so neither file nears the
/// line ceiling (split-early convention).
@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-exec-dedup-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.loadConfig()
    return core
}

/// Generous hang-guard, matching `ExecTests` (#344): a passing run
/// exits the instant the reap lands; the deadline only bounds a hang.
private let hangGuard: TimeInterval = 30

@MainActor
private func awaitReaped(
    _ core: KiwiCore,
    timeout: TimeInterval = hangGuard
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while core.exec.runningCount > 0, Date() < deadline {
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}

@Suite("Exec dedup & default timeout", .serialized)
@MainActor
struct ExecDedupTests {
    @Test("dedup skips a command already in flight")
    func dedupSkipsInFlight() {
        let core = makeCore()
        // First launch takes the slot; the identical second is
        // skipped and returns nil, leaving exactly one child.
        let first = core.exec.launch("sleep 5", dedup: true)
        #expect(first != nil)
        let second = core.exec.launch("sleep 5", dedup: true)
        #expect(second == nil)
        #expect(core.exec.runningCount == 1)
    }

    @Test("dedup:false lets identical commands run in parallel")
    func noDedupAllowsParallel() {
        let core = makeCore()
        core.exec.launch("sleep 5", dedup: false)
        core.exec.launch("sleep 5", dedup: false)
        #expect(core.exec.runningCount == 2)
    }

    @Test("dedup clears once the in-flight child is reaped")
    func dedupClearsAfterReap() async throws {
        let core = makeCore()
        // A fast child holds the dedup slot only until it reaps;
        // afterwards the same command may launch again.
        core.exec.launch("true", dedup: true)
        try await awaitReaped(core)
        let again = core.exec.launch("true", dedup: true)
        #expect(again != nil)
    }

    @Test("KiwiDesk.exec dedups identical commands by default")
    func luaExecDedupsByDefault() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        #expect(lua.run("p1 = KiwiDesk.exec('sleep 5')").succeeded)
        #expect(lua.run("p2 = KiwiDesk.exec('sleep 5')").succeeded)
        // First poke gets a pid; the second is skipped (nil).
        if case .number(let pid) = lua.global("p1") {
            #expect(pid > 0)
        } else {
            Issue.record("expected a pid for the first exec")
        }
        #expect(lua.global("p2") == .none)
        #expect(core.exec.runningCount == 1)
    }

    @Test("dedup=false via the fourth arg runs both")
    func luaExecDedupOptOut() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        #expect(
            lua.run(
                "KiwiDesk.exec('sleep 5', nil, nil, false)"
            ).succeeded
        )
        #expect(
            lua.run(
                "KiwiDesk.exec('sleep 5', nil, nil, false)"
            ).succeeded
        )
        #expect(core.exec.runningCount == 2)
    }

    @Test("launcher warns once the outstanding count crosses 20")
    func warnsAtThreshold() {
        let core = makeCore()
        var logs: [String] = []
        core.exec.onLog = { logs.append($0) }
        for _ in 0..<20 {
            core.exec.launch("sleep 5", dedup: false)
        }
        #expect(core.exec.runningCount == 20)
        #expect(
            logs.contains { $0.contains("children outstanding") }
        )
    }

    @Test("absent timeout falls back to the generous default")
    func defaultTimeoutConstant() {
        // The default only bounds a genuine hang; the behavioral
        // watchdog path is proven in `ExecTests.execTimeout`.
        #expect(KiwiCore.defaultExecTimeout == 30)
    }

    @Test("explicit timeout 0 disables the watchdog, not instant-kill")
    func zeroTimeoutMeansNoLimit() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // 0 must map to "no watchdog", NOT a 0-second deadline that
        // SIGTERMs the child immediately. A long-lived child proves
        // it by gap: a mis-parsed 0-as-deadline would terminate and
        // reap well within reapGrace (2s), while no-limit keeps it
        // running. The child outlives any starved poll (#344), so
        // the check can't flake on a late resume.
        #expect(
            lua.run("z = KiwiDesk.exec('sleep 30', nil, 0)").succeeded
        )
        #expect(core.exec.runningCount == 1)
        if case .number(let pid) = lua.global("z") {
            #expect(pid > 0)
        } else {
            Issue.record("expected a pid for an accepted exec")
        }
        try await Task.sleep(nanoseconds: 2_500_000_000)
        #expect(core.exec.runningCount == 1)
    }
}
