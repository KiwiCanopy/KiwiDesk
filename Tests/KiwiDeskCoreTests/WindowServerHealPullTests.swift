import Foundation
import Testing

@testable import KiwiDeskCore

/// **A WindowServer create runs one wake sweep per grace** (#1877),
/// beside the heal's cadence rather than in its place. A burst of
/// creates must never push the sweep later, or a chatty app's
/// popups starve it.
@Suite("WindowServer create pulls a wake sweep (#1877)")
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

    @Test("a create schedules the sweep; a burst keeps it")
    func burstKeepsTheFirstPull() throws {
        let core = runningCore()
        core.windowServerChanged(.created, id: WindowID(41))
        let first = try #require(core.deferred.task(for: .adoptionHealWake))
        core.windowServerChanged(.created, id: WindowID(42))
        let second = core.deferred.task(for: .adoptionHealWake)
        #expect(second == first, "a burst re-armed the pull")
    }

    @Test("the pull runs one wake sweep and leaves the heal alone")
    func pullRunsTheWakeSweep() async throws {
        let core = runningCore()
        core.windowServerChanged(.created, id: WindowID(41))
        let wait = try #require(
            core.deferred.task(for: .adoptionHealWake)
        )
        let reads = CensusReads()
        core.eventLoop.onScreenNormalWindowIDs = {
            reads.count()
            return [:]
        }
        await wait.value
        // The wait handed over to the census read, whose own
        // completion clears the handle: on a loaded runner it can
        // be gone before this line, so the read count is the proof.
        await core.deferred.task(for: .adoptionHealWake)?.value
        #expect(reads.total == 1)
        #expect(!core.deferred.isScheduled(.adoptionHealWake))
        // The heal's own cadence is not this pull's to move.
        #expect(!core.deferred.isScheduled(.adoptionHeal))
        #expect(!core.deferred.isScheduled(.adoptionHealRead))
    }

    /// The census is read off the main actor.
    private final class CensusReads: @unchecked Sendable {
        private let lock = NSLock()
        private var reads = 0
        func count() { lock.withLock { reads += 1 } }
        var total: Int { lock.withLock { reads } }
    }

    @Test("a stopped loop pulls nothing")
    func stoppedLoopPullsNothing() {
        let core = makeTestCore()
        core.windowServerChanged(.created, id: WindowID(41))
        #expect(!core.deferred.isScheduled(.adoptionHealWake))
    }
}
