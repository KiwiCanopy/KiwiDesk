import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The adoption heal's delivery half (#675): the self-rearming
/// sweep task and the one-shot transient re-track.
/// `AdoptionHealTests` pins what a sweep does; this suite pins
/// that the scheduled tasks actually run one and come back. The
/// remaining unpinned link — `start()` calling
/// `scheduleAdoptionHeal()` — is carried as an obligation in
/// accessibility.md, because `start()` is not test-drivable
/// (the `scheduleStartupSweep` precedent).
///
/// The awaits ride millisecond timings assigned through the
/// stored seams (`timings.adoptionHealInterval`,
/// `timings.transientRetrackDelay`); production keeps the defaults
/// declared on `KiwiCore`.
@MainActor
@Suite("Adoption heal scheduling (#675)")
struct AdoptionHealScheduleTests {
    @MainActor
    private final class Box {
        var windowQueries = 0
        /// Read off the main actor (#1956), so counted under a lock.
        let census = CensusCounter()
        var censusReads: Int { census.count }
    }

    private final class CensusCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var reads = 0
        func note() { lock.withLock { reads += 1 } }
        var count: Int { lock.withLock { reads } }
    }

    /// Inert healthy observer: attach installs it, nothing
    /// fires, registration never needs repair (#675 — health is
    /// stated, never defaulted).
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        let needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    private func makeCore() -> (core: KiwiCore, box: Box) {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-heal-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        let box = Box()
        let loop = core.eventLoop
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.activationPolicy = { _ in .regular }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.runningApplications = { [] }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        let counter = box.census
        loop.onScreenNormalWindowIDs = {
            counter.note()
            return [:]
        }
        runWholeScan(loop)
        return (core, box)
    }

    /// The whole scan in one turn. Production chunks it and
    /// hands the run loop back between chunks (`KiwiCore+Boot`,
    /// #801) — a suite has nothing to yield to, so it drains with
    /// no budget.
    private func runWholeScan(_ loop: EventLoop) {
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
    }

    @Test("the scheduled heal task sweeps and re-arms")
    func healTaskSweepsAndRearms() async {
        let (core, box) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        core.timings.adoptionHealInterval = .milliseconds(1)
        core.scheduleAdoptionHeal()
        let armed = core.deferred.task(for: .adoptionHeal)
        await armed?.value
        // The census is read off the main actor (#1956); the sweep
        // and the re-arm land when it answers.
        let read = core.deferred.task(for: .adoptionHealRead)
        #expect(read != nil)
        await read?.value
        // The fired task really swept (the census was read) …
        #expect(box.censusReads == 1)
        // … and re-armed itself: the slot now holds a NEW task,
        // not the finished one.
        let rearmed = core.deferred.task(for: .adoptionHeal)
        #expect(rearmed != nil)
        #expect(rearmed != armed)
    }

    /// Where the census is read, recorded from the reading thread.
    private final class ThreadRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var reads: [Bool] = []
        func note() {
            lock.withLock { reads.append(Thread.isMainThread) }
        }
        var onMain: [Bool] { lock.withLock { reads } }
    }

    /// #1956: the census read waits for WindowServer to take this
    /// process's pending window updates, so the scheduled sweep
    /// reads it off the main actor.
    @Test("the scheduled heal reads its census off the main actor")
    func healReadsCensusOffMain() async {
        let (core, _) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        let recorder = ThreadRecorder()
        core.eventLoop.onScreenNormalWindowIDs = {
            recorder.note()
            return [:]
        }
        core.timings.adoptionHealInterval = .milliseconds(1)
        core.scheduleAdoptionHeal()
        await core.deferred.task(for: .adoptionHeal)?.value
        let read = core.deferred.task(for: .adoptionHealRead)
        #expect(read != nil)
        await read?.value
        #expect(recorder.onMain == [false])
    }

    /// A semaphore wait, kept out of the async context.
    nonisolated private static func block(on semaphore: DispatchSemaphore) {
        semaphore.wait()
    }

    /// #1956: teardown cancels a read in flight, and a cancelled
    /// read neither sweeps nor re-arms — a stopped core's heal
    /// chain stays stopped.
    @Test("a heal read cancelled in flight never re-arms")
    func cancelledReadDoesNotRearm() async {
        let (core, box) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let counter = box.census
        core.eventLoop.onScreenNormalWindowIDs = {
            counter.note()
            started.signal()
            release.wait()
            return [:]
        }
        core.timings.adoptionHealInterval = .milliseconds(1)
        core.scheduleAdoptionHeal()
        await core.deferred.task(for: .adoptionHeal)?.value
        let read = core.deferred.task(for: .adoptionHealRead)
        #expect(read != nil)
        await Task.detached { Self.block(on: started) }.value
        core.deferred.cancelAll()
        release.signal()
        await read?.value
        #expect(box.censusReads == 1)
        #expect(core.deferred.task(for: .adoptionHeal) == nil)
    }

    @Test("the re-track task reconciles every queued pid")
    func retrackTaskReconcilesQueuedPids() async {
        let (core, box) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        core.timings.transientRetrackDelay = .milliseconds(1)
        // The pid needs its observer (a reconcile of an
        // unobserved pid detaches and returns), so attach the
        // fake first — the drop then queues the pid and fires
        // the wire bootstrap installed (`onTransientDrop` →
        // `scheduleTransientRetrack`).
        core.eventLoop.attach(
            pid: 676_676,
            activationPolicy: .regular,
            ref: AppRef(bundleID: "test.kiwi.drop", name: "Drop"),
            scanWindowsAtAttach: false
        )
        core.eventLoop.markTransientDrop(
            pid: 676_676,
            id: WindowID(7)
        )
        await core.deferred.task(for: .transientRetrack)?.value
        // The fired task drained the queue and reconciled the
        // pid — visible as its AX window snapshot.
        #expect(box.windowQueries == 1)
        #expect(core.eventLoop.drainPendingRetrack().isEmpty)
    }
}
