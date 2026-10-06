import Foundation
import Testing

@testable import KiwiDeskCore

/// A boot into a locked session lists windows whose elements
/// answer as the application, so the heal quiets every one of
/// them and never asks again (#1285, measured on device). A
/// return leg — unlock or wake — re-opens that ledger, whether or
/// not a wake replay is armed.
@MainActor
@Suite("Heal re-opens on a return leg (#1285)")
struct HealReopenOnReturnTests {
    private let pid: pid_t = 1285
    private let id = WindowID(12_850)

    @Test("forgetting the ledger re-opens the heal's gate")
    func forgetReopensTheGate() {
        let loop = EventLoop()
        loop.onLog = { _ in }
        loop.healQuiet[pid] = [id]
        #expect(!loop.opensGate(pid: pid, missing: [id]))
        loop.forgetHealQuiet()
        #expect(loop.healQuiet.isEmpty)
        #expect(loop.opensGate(pid: pid, missing: [id]))
    }

    @Test("a return leg fires onReturn with no replay and disabled")
    func returnFiresWithoutAReplay() {
        let manager = SleepWakeManager()
        manager.onLog = { _ in }
        manager.isEnabled = false
        var returns = 0
        manager.onReturn = { returns += 1 }
        manager.systemDidReturn(.direct)
        #expect(returns == 1)
        manager.systemWillRest(.lock)
        #expect(returns == 1)
    }

    @Test("the core wires a return leg to the heal's ledger")
    func coreWiresReturnToTheLedger() {
        let core = makeTestCore()
        core.eventLoop.healQuiet[pid] = [id]
        core.sleepWake.systemDidReturn(.direct)
        #expect(core.eventLoop.healQuiet.isEmpty)
    }
}
