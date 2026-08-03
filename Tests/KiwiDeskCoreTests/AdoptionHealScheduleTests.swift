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
/// The awaits ride overridden millisecond schedules; production
/// keeps the shipped cadence (the override seam is nil there).
@MainActor
@Suite("Adoption heal scheduling (#675)")
struct AdoptionHealScheduleTests {
    @MainActor
    private final class Box {
        var censusReads = 0
        var windowQueries = 0
    }

    /// Inert healthy observer: attach installs it, nothing fires.
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        func observe(window: AXUIElement) {}
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
        loop.onScreenNormalWindowCounts = {
            box.censusReads += 1
            return [:]
        }
        loop.start()
        return (core, box)
    }

    @Test("the scheduled heal task sweeps and re-arms")
    func healTaskSweepsAndRearms() async {
        let (core, box) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        core.adoptionHealIntervalOverride = .milliseconds(1)
        core.scheduleAdoptionHeal()
        let armed = core.deferred.task(for: .adoptionHeal)
        await armed?.value
        // The fired task really swept (the census was read) …
        #expect(box.censusReads == 1)
        // … and re-armed itself: the slot now holds a NEW task,
        // not the finished one.
        let rearmed = core.deferred.task(for: .adoptionHeal)
        #expect(rearmed != nil)
        #expect(rearmed != armed)
    }

    @Test("the re-track task reconciles every queued pid")
    func retrackTaskReconcilesQueuedPids() async {
        let (core, box) = makeCore()
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        core.transientRetrackDelayOverride = .milliseconds(1)
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
