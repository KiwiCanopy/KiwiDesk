import Foundation
import Testing

@testable import KiwiDeskCore

/// **A WindowServer create pulls the adoption heal forward, once
/// per grace** (#1877): the heal's census, gate and unwatched-app
/// attach do the adopting, so a create only moves WHEN it runs. A
/// burst of creates must never push the pulled heal later, or a
/// chatty app's popups starve it.
@Suite("WindowServer create pulls the heal (#1877)")
@MainActor
struct WindowServerHealPullTests {
    private func runningCore() -> KiwiCore {
        let core = makeTestCore()
        core.eventLoop.registersWorkspaceObservers = false
        core.eventLoop.runningApplications = { [] }
        core.eventLoop.visiblePIDs = { [] }
        core.eventLoop.onScreenNormalWindowIDs = { [:] }
        core.eventLoop.applyAXMessagingTimeout = { _ in }
        #expect(core.eventLoop.beginScan())
        core.eventLoop.scanChunk(budget: nil)
        return core
    }

    @Test("a create schedules the pulled heal; a burst keeps it")
    func burstKeepsTheFirstPull() throws {
        let core = runningCore()
        core.windowServerChanged(.created, id: WindowID(41))
        let first = try #require(core.deferred.task(for: .adoptionHealWake))
        core.windowServerChanged(.created, id: WindowID(42))
        let second = core.deferred.task(for: .adoptionHealWake)
        #expect(second == first, "a burst re-armed the pull")
    }

    @Test("the pulled heal runs the sweep and re-arms the cadence")
    func pulledHealSweeps() async throws {
        let core = runningCore()
        core.windowServerChanged(.created, id: WindowID(41))
        let pull = try #require(core.deferred.task(for: .adoptionHealWake))
        await pull.value
        #expect(!core.deferred.isScheduled(.adoptionHealWake))
        let read = try #require(core.deferred.task(for: .adoptionHealRead))
        await read.value
        #expect(core.deferred.isScheduled(.adoptionHeal))
    }

    @Test("a stopped loop pulls nothing")
    func stoppedLoopPullsNothing() {
        let core = makeTestCore()
        core.windowServerChanged(.created, id: WindowID(41))
        #expect(!core.deferred.isScheduled(.adoptionHealWake))
    }
}
