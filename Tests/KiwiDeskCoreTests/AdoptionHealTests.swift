import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The adoption heal's gate and repair funnels (#675). Every
/// event-driven adoption path can go silent at once for a
/// fresh-launch app — a failed `AXObserverAddNotification` emits
/// nothing, ever, and the non-nil `observers[pid]` entry blocks
/// any re-attach — so `healSweep` is the pass guaranteed to
/// come. This suite pins its gate (census vs tracked count),
/// its self-quieting, the registration repair on both
/// touchpoints, and the missed-attach recovery. Everything
/// drives the funnels through the injected machine seams
/// (tests.md); no real app, observer, or AX call is touched.
@MainActor
@Suite("Adoption heal (#675)")
struct AdoptionHealTests {
    /// Fake observer whose registration health the suite steers.
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        var repairs = 0
        func observe(window: AXUIElement) {}
        func repairRegistration() {
            repairs += 1
            needsRegistrationRepair = false
        }
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var windowQueries = 0
        var censusReads = 0
        var counts: [pid_t: Int] = [:]
        var observer = FakeObserver()
        var drops = 0
    }

    private let pid: pid_t = 675_675
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.heal", name: "Heal")
    }
    private var app: RunningApp {
        RunningApp(
            pid: pid,
            activationPolicy: .regular,
            ref: ref
        )
    }

    private func makeLoop(started: Bool = true) -> (
        loop: EventLoop, box: Box
    ) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [self.app] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in box.observer }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowCounts = {
            box.censusReads += 1
            return box.counts
        }
        loop.onTransientDrop = { box.drops += 1 }
        if started {
            loop.runningApplications = { [] }
            loop.start()
            loop.runningApplications = { [self.app] }
        }
        return (loop, box)
    }

    @Test("a census excess over the tracked count reconciles")
    func excessFiresAReconcile() {
        let (loop, box) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        #expect(box.windowQueries == 0)
        box.counts = [pid: 1]
        loop.healSweep()
        #expect(box.windowQueries == 1)
    }

    @Test("a matching census stays free of AX reads")
    func matchingCensusStaysQuiet() {
        let (loop, box) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.healSweep()
        #expect(box.censusReads == 1)
        #expect(box.windowQueries == 0)
    }

    @Test("a fruitless heal quiets until the census moves")
    func fruitlessHealQuietsUntilTheCensusMoves() {
        // The window the census sees never becomes trackable
        // (axWindows stays empty — the ignored-panel shape), so
        // the gate must stop paying a reconcile per tick.
        let (loop, box) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        box.counts = [pid: 1]
        loop.healSweep()
        #expect(box.windowQueries == 1)
        loop.healSweep()
        #expect(box.windowQueries == 1)
        // A moved count is new evidence: the gate re-fires once.
        box.counts = [pid: 2]
        loop.healSweep()
        #expect(box.windowQueries == 2)
    }

    @Test("the sweep repairs a broken registration")
    func sweepRepairsABrokenRegistration() {
        let (loop, box) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        box.observer.needsRegistrationRepair = true
        loop.healSweep()
        #expect(box.observer.repairs == 1)
        // Healthy again: the next pass leaves it alone.
        loop.healSweep()
        #expect(box.observer.repairs == 1)
    }

    @Test("a reconcile repairs a broken registration")
    func reconcileRepairsABrokenRegistration() {
        // The event-paced half of the retry: an app activation
        // reaches reconcile long before the next sweep tick.
        let (loop, box) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        box.observer.needsRegistrationRepair = true
        loop.reconcile(pid: pid, app: ref)
        #expect(box.observer.repairs == 1)
    }

    @Test("an app whose launch-time attach failed is attached")
    func missedAttachIsHealed() {
        // `AXObserverCreate` can refuse a not-yet-ready app:
        // the pid then has windows per the census and no
        // observer at all.
        let (loop, box) = makeLoop()
        #expect(!loop.observes(pid: pid))
        box.counts = [pid: 1]
        loop.healSweep()
        #expect(loop.observes(pid: pid))
        #expect(box.windowQueries == 1)
    }

    @Test("a sweep before start is inert")
    func sweepBeforeStartIsInert() {
        let (loop, box) = makeLoop(started: false)
        box.counts = [pid: 1]
        loop.healSweep()
        #expect(box.censusReads == 0)
        #expect(box.windowQueries == 0)
    }

    @Test("a transient drop queues one re-track per window")
    func transientDropQueuesOnce() {
        let (loop, box) = makeLoop()
        let id = WindowID(42)
        loop.markTransientDrop(pid: pid, id: id)
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 1)
        #expect(loop.drainPendingRetrack() == [pid])
        // Drained: nothing left for the scheduled task.
        #expect(loop.drainPendingRetrack().isEmpty)
        // The ledger clears with its app, so a relaunch reusing
        // the pid gets a fresh retry.
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 1)
        loop.detach(pid: pid, restoreEnhancedUI: false)
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 2)
    }
}
