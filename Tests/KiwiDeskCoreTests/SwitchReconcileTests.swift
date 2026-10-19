import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A Desktop switch's bulk re-sync reads off the main actor and
/// applies in one fold** (#2347). Driven through the batch's two
/// halves on stubbed seams, every list read and the bound captured
/// for the test to pump. Two apps, each tracking one window its
/// list answers only where a test says, so a read that applied
/// destroys it — which is how a test sees what applied, and when.
@Suite("Switch reconcile batch (#2347)")
@MainActor
struct SwitchReconcileTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    @MainActor
    private final class Box {
        var destroyed: [WindowID] = []
        /// Destroys that landed inside a fold, while it applied.
        var foldedDestroys: [WindowID] = []
        var inFold = false
        var folds = 0
        var listed: [pid_t: WindowID] = [:]
        var listReads: [pid_t: Int] = [:]
        var census: [pid_t: Set<WindowID>] = [:]
        var work: [@Sendable () -> Void] = []
        var bounds: [@MainActor @Sendable () -> Void] = []

        func drain() {
            while !work.isEmpty { work.removeFirst()() }
        }

        func runOne() { work.removeFirst()() }

        func runLast() { work.removeLast()() }
    }

    private let first: pid_t = 909_101
    private let second: pid_t = 909_102
    private let firstID = WindowID(31)
    private let secondID = WindowID(32)

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = {
            MainActor.assumeIsolated { box.census }
        }
        loop.appIsHidden = { _ in false }
        loop.frontmostPID = { nil }
        loop.axWindows = { pid in
            let listed = MainActor.assumeIsolated {
                box.listReads[pid, default: 0] += 1
                return box.listed[pid]
            }
            return listed == nil ? [] : [AXUIElementCreateApplication(pid)]
        }
        loop.resolveWindowID = { element in
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            return MainActor.assumeIsolated { box.listed[pid] }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.axReads.dispatchOverride = { _, work in
            box.work.append(work)
        }
        loop.switchReads.scheduleBound = { _, work in
            box.bounds.append(work)
        }
        loop.foldsSwitchResync = { body in
            box.folds += 1
            box.inFold = true
            body()
            box.inFold = false
        }
        loop.onEvent = { [weak loop] event in
            if case .windowDestroyed(let id, _) = event {
                box.destroyed.append(id)
                if box.inFold, loop?.switchReads.applying == true {
                    box.foldedDestroys.append(id)
                }
            }
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        for (pid, id) in [(first, firstID), (second, secondID)] {
            loop.attach(
                pid: pid,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "test.kiwi.switch\(pid)", name: "S"),
                scanWindowsAtAttach: false
            )
            loop.elements[pid] = [id: AXUIElementCreateApplication(pid)]
        }
        return (loop, box)
    }

    private func switchDesktop(_ loop: EventLoop) {
        loop.lastDesktopChange = Date()
        loop.beginSwitchReconcile()
        loop.requestSwitchReads()
    }

    @Test("nothing applies before every read lands, then one fold")
    func appliesInOneFold() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        #expect(box.work.count == 2, "one read per gated app")
        #expect(box.destroyed.isEmpty, "applied inline")
        box.runOne()
        #expect(box.destroyed.isEmpty, "applied before the batch")
        #expect(loop.switchReads.isPending)
        box.runOne()
        #expect(Set(box.destroyed) == [firstID, secondID])
        #expect(box.folds == 1)
        #expect(!loop.switchReads.isPending)
        #expect(loop.switchReads.batch == nil)
    }

    @Test("the bound applies what landed; a straggler applies alone")
    func boundCutsTheBatch() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        box.runOne()
        #expect(box.bounds.count == 1)
        box.bounds.removeFirst()()
        #expect(box.destroyed.count == 1, "the landed read")
        #expect(box.folds == 1)
        #expect(!loop.switchReads.isPending)
        #expect(loop.switchReads.isOutstanding(second))
        box.runOne()
        #expect(box.destroyed.count == 2)
        #expect(box.folds == 2, "the straggler's own fold")
        #expect(!loop.switchReads.isOutstanding(second))
        // The straggler's lone apply is a late read, not a reveal.
        #expect(box.foldedDestroys == [firstID])
    }

    @Test("a superseded switch's reads apply nothing")
    func newerSwitchSupersedes() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        switchDesktop(loop)
        // The stale switch's reads still list both windows; the
        // newer switch's list nothing, and only those may apply.
        box.listed = [first: firstID, second: secondID]
        box.runOne()
        box.runOne()
        box.listed = [:]
        box.drain()
        #expect(box.folds == 1)
        #expect(Set(box.destroyed) == [firstID, secondID])
        for bound in box.bounds { bound() }
        #expect(box.folds == 1, "a stale bound applied")
    }

    @Test("a newer reading of an app outranks the batch's")
    func appliesInReadOrder() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        // The batch reads the first app's list empty…
        box.runOne()
        // …then a later per-app read lists its window and applies.
        box.listed[first] = firstID
        loop.reconcileOffMain(
            pid: first,
            app: AppRef(pid: first),
            coalesceTabs: false
        )
        box.runLast()
        #expect(box.destroyed.isEmpty)
        box.drain()
        #expect(box.destroyed == [secondID])
        #expect(loop.elements[first]?[firstID] != nil)
    }

    @Test("a per-app read landing first applies inside the fold")
    func perAppReadIsHeldForTheFold() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        // An activation's read of the first app lands before the
        // batch's own.
        loop.reconcileOffMain(
            pid: first,
            app: AppRef(pid: first),
            coalesceTabs: false
        )
        box.runLast()
        #expect(box.destroyed.isEmpty, "applied outside the fold")
        box.drain()
        #expect(box.folds == 1)
        #expect(Set(box.foldedDestroys) == [firstID, secondID])
    }

    @Test("a queued read is ordered by when it ran, not when asked")
    func queuedReadOrdersByWhenItRan() {
        let (loop, box) = makeLoop()
        box.listed = [first: firstID, second: secondID]
        switchDesktop(loop)
        // The newer switch's reads queue behind the first's.
        switchDesktop(loop)
        loop.reconcileOffMain(
            pid: first,
            app: AppRef(pid: first),
            coalesceTabs: false
        )
        // The stale batch's two reads run; the newer batch's are
        // dispatched only then, behind the per-app read.
        box.runOne()
        box.runOne()
        box.runOne()  // the per-app read: lists the window
        // The first app's window closes; the newer batch's read,
        // asked BEFORE the per-app read but run after it, sees it.
        box.listed[first] = nil
        box.drain()
        #expect(box.destroyed.contains(firstID))
        #expect(!box.destroyed.contains(secondID))
    }

    @Test("an older held reading sweeps nothing the newer one lists")
    func olderHeldReadingIsStale() {
        let (loop, box) = makeLoop()
        // A per-app read runs before the switch's, listing nothing…
        loop.reconcileOffMain(
            pid: first,
            app: AppRef(pid: first),
            coalesceTabs: false
        )
        switchDesktop(loop)
        box.runOne()
        #expect(box.destroyed.isEmpty, "applied outside the fold")
        // …and the batch's newer reads list both windows.
        box.listed = [first: firstID, second: secondID]
        box.drain()
        #expect(box.folds == 1)
        #expect(box.destroyed.isEmpty)
    }

    @Test("owed work runs after the fold, in order")
    func afterFoldWaitsForTheFold() {
        let (loop, box) = makeLoop()
        var ran: [Int] = []
        loop.switchReads.onApplied = { ran.append(-1) }
        switchDesktop(loop)
        loop.afterSwitchReads { ran.append(box.destroyed.count) }
        loop.afterSwitchReads { ran.append(9) }
        #expect(ran.isEmpty)
        box.drain()
        // The held bars are paid ahead of the owed work.
        #expect(ran == [-1, 2, 9])
        loop.afterSwitchReads { ran.append(3) }
        #expect(ran == [-1, 2, 9, 3], "no batch pending: at once")
    }

    @Test("the settle waits for the fold, and a newer switch drops it")
    func settleTakesOneSlot() {
        let (loop, box) = makeLoop()
        var settled: [Int] = []
        switchDesktop(loop)
        loop.settleAfterSwitchReads { settled.append(1) }
        switchDesktop(loop)
        loop.settleAfterSwitchReads { settled.append(2) }
        #expect(settled.isEmpty, "settled before the fold")
        box.drain()
        #expect(settled == [2])
        loop.settleAfterSwitchReads { settled.append(3) }
        #expect(settled == [2, 3], "no batch pending: settle at once")
    }

    @Test("a newer switch that parks no settle runs none")
    func newerSwitchEmptiesTheSlot() {
        let (loop, box) = makeLoop()
        var settled = false
        switchDesktop(loop)
        loop.settleAfterSwitchReads { settled = true }
        switchDesktop(loop)
        box.drain()
        #expect(!settled)
    }

    @Test("the arrival sweep leaves an app whose read is owed")
    func arrivalSweepSkipsAnOwedRead() {
        let (loop, box) = makeLoop()
        // The first app shows a window it does not track yet.
        loop.elements[first] = [:]
        box.census = [first: [firstID]]
        switchDesktop(loop)
        #expect(loop.switchReads.isOutstanding(first))
        box.listed[first] = firstID
        let before = box.listReads[first, default: 0]
        loop.reconcileOnScreenArrivals()
        #expect(box.listReads[first, default: 0] == before, "read it")
    }

    @Test("a stop drops the batch and what waits on it")
    func stopDropsTheBatch() {
        let (loop, box) = makeLoop()
        var settled = false
        switchDesktop(loop)
        loop.settleAfterSwitchReads { settled = true }
        loop.stop()
        box.drain()
        #expect(!settled)
    }

    @Test("the bound sits under the grace and the settle")
    func boundsAreOrdered() {
        #expect(
            SwitchReconcile.bound < EventLoop.spaceSwitchCoalesceGrace
        )
        #expect(
            SwitchReconcile.bound
                < Double(KiwiCore.desktopSettleMs) / 1000,
            "the settle's delay"
        )
        #expect(
            SwitchReconcile.stragglerLimit < KiwiCore.inFlightWindow
        )
    }
}
