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
/// come. This suite pins its gate (census id MEMBERSHIP against
/// the tracked ids — a count gate let one tracked overlay shadow
/// a missed document window forever), its per-id self-quieting,
/// the registration repair on both touchpoints, and the
/// missed-attach recovery. Everything drives the funnels through
/// the injected machine seams (tests.md); the only AX object a
/// test creates is an app element used as an inert dictionary
/// value, never messaged.
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
        var census: [pid_t: Set<WindowID>] = [:]
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
        loop.onScreenNormalWindowIDs = {
            box.censusReads += 1
            return box.census
        }
        loop.onTransientDrop = { box.drops += 1 }
        if started {
            loop.runningApplications = { [] }
            loop.start()
            loop.runningApplications = { [self.app] }
        }
        return (loop, box)
    }

    private func attach(_ loop: EventLoop) {
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
    }

    /// An inert AX value for seeding `elements` directly — an
    /// app element is never messaged by the sweep's gate.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    @Test("an untracked census id fires a reconcile")
    func untrackedIDFiresAReconcile() {
        let (loop, box) = makeLoop()
        attach(loop)
        #expect(box.windowQueries == 0)
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.windowQueries == 1)
    }

    @Test("an empty census stays free of AX reads")
    func emptyCensusStaysQuiet() {
        let (loop, box) = makeLoop()
        attach(loop)
        loop.healSweep()
        #expect(box.censusReads == 1)
        #expect(box.windowQueries == 0)
    }

    @Test("a tracked overlay cannot shadow a missed window")
    func trackedOverlayCannotShadow() {
        // The count-gate defect the review caught: one tracked
        // raised-layer overlay (absent from the layer-0 census)
        // made ws == tracked, and the missed document window
        // was shadowed forever. Membership cannot be shadowed:
        // census id 9 is untracked no matter what else is.
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(5): dummyElement]
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.windowQueries == 1)
    }

    @Test("a fully tracked census stays free of AX reads")
    func fullyTrackedCensusStaysQuiet() {
        let (loop, box) = makeLoop()
        attach(loop)
        loop.elements[pid] = [WindowID(9): dummyElement]
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.windowQueries == 0)
    }

    @Test("a fruitless heal quiets those ids until a new one")
    func fruitlessHealQuietsPerID() {
        // The census id never becomes trackable (axWindows stays
        // empty — the ignored-panel shape), so the gate must
        // stop paying a reconcile per tick for exactly that id.
        let (loop, box) = makeLoop()
        attach(loop)
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.windowQueries == 1)
        loop.healSweep()
        #expect(box.windowQueries == 1)
        // A NEW id is new evidence: the gate re-opens once,
        // while the old id stays hushed.
        box.census = [pid: [WindowID(9), WindowID(10)]]
        loop.healSweep()
        #expect(box.windowQueries == 2)
        loop.healSweep()
        #expect(box.windowQueries == 2)
    }

    @Test("the sweep repairs a broken registration")
    func sweepRepairsABrokenRegistration() {
        let (loop, box) = makeLoop()
        attach(loop)
        box.observer.needsRegistrationRepair = true
        // Repair is tied to the pid owning census windows —
        // the deaf-observer case IS a window nobody adopted.
        box.census = [pid: [WindowID(9)]]
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
        attach(loop)
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
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(loop.observes(pid: pid))
        #expect(box.windowQueries == 1)
    }

    @Test("a sweep before start is inert")
    func sweepBeforeStartIsInert() {
        let (loop, box) = makeLoop(started: false)
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.censusReads == 0)
        #expect(box.windowQueries == 0)
    }

    @Test("detach clears the quiet gate for a reused pid")
    func detachClearsTheQuietGate() {
        // A quieted id must die with its app: a relaunch
        // reusing the pid starts with a fresh gate, not a hush
        // inherited from the previous process over the same
        // window ids.
        let (loop, box) = makeLoop()
        attach(loop)
        box.census = [pid: [WindowID(9)]]
        loop.healSweep()
        #expect(box.windowQueries == 1)
        loop.detach(pid: pid, restoreEnhancedUI: false)
        // Same census ids, fresh process: the missed-attach
        // branch must fire, not inherit the hush.
        loop.healSweep()
        #expect(box.windowQueries == 2)
    }

    @Test("a transient drop queues one re-track per window")
    func transientDropQueuesOnce() {
        let (loop, box) = makeLoop()
        let id = WindowID(42)
        loop.markTransientDrop(pid: pid, id: id)
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 1)
        // A further DISTINCT drop rides the already-armed
        // one-shot instead of pushing its deadline back.
        loop.markTransientDrop(pid: pid, id: WindowID(43))
        #expect(box.drops == 1)
        #expect(loop.drainPendingRetrack() == [pid])
        // Drained: nothing left for the scheduled task, and the
        // next drop re-arms from idle.
        #expect(loop.drainPendingRetrack().isEmpty)
        loop.markTransientDrop(pid: pid, id: WindowID(44))
        #expect(box.drops == 2)
        // The ledger clears with its app, so a relaunch reusing
        // the pid gets a fresh retry.
        _ = loop.drainPendingRetrack()
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 2)
        loop.detach(pid: pid, restoreEnhancedUI: false)
        loop.markTransientDrop(pid: pid, id: id)
        #expect(box.drops == 3)
    }

    @Test("the transient retry ledger is capped per app")
    func transientRetryLedgerIsCapped() {
        // An overlay-minting app must not grow the ledger for
        // the session: past the cap it degrades to the sweep
        // and incidental reconciles.
        let (loop, box) = makeLoop()
        for n in 0..<EventLoop.transientRetryCap {
            loop.markTransientDrop(
                pid: pid,
                id: WindowID(UInt32(1000 + n))
            )
            _ = loop.drainPendingRetrack()
        }
        let fires = box.drops
        loop.markTransientDrop(pid: pid, id: WindowID(1))
        #expect(box.drops == fires)
        #expect(loop.drainPendingRetrack().isEmpty)
    }
}
