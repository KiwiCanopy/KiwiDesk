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
        var folds = 0
        var listed: [pid_t: WindowID] = [:]
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
            let listed = MainActor.assumeIsolated { box.listed[pid] }
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
            body()
        }
        loop.onEvent = { event in
            if case .windowDestroyed(let id, _) = event {
                box.destroyed.append(id)
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
    }

    @Test("a superseded switch's reads apply nothing")
    func newerSwitchSupersedes() {
        let (loop, box) = makeLoop()
        switchDesktop(loop)
        switchDesktop(loop)
        box.drain()
        #expect(box.folds == 1)
        #expect(box.destroyed.count == 2)
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

    @Test("the census is judged by the grace the read began in")
    func graceIsTakenAtTheRead() {
        let (loop, box) = makeLoop()
        // The compositor still shows both windows, as it does
        // through a switch's transition (#1023).
        box.census = [first: [firstID], second: [secondID]]
        switchDesktop(loop)
        // The apply lands after the grace has passed.
        loop.lastDesktopChange = .distantPast
        box.drain()
        #expect(Set(box.destroyed) == [firstID, secondID])
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

    @Test("the arrival sweep leaves an app whose read is owed")
    func arrivalSweepSkipsAnOwedRead() {
        let (loop, box) = makeLoop()
        // The first app shows a window it does not track yet.
        loop.elements[first] = [:]
        box.census = [first: [firstID]]
        switchDesktop(loop)
        #expect(loop.switchReads.isOutstanding(first))
        box.listed[first] = firstID
        loop.reconcileOnScreenArrivals()
        #expect(loop.elements[first]?[firstID] == nil, "read it")
    }

    @Test("a stop drops the batch and what waits on it")
    func stopDropsTheBatch() {
        let (loop, box) = makeLoop()
        var settled = false
        switchDesktop(loop)
        loop.settleAfterSwitchReads { settled = true }
        loop.stop()
        box.drain()
        #expect(box.destroyed.isEmpty)
        #expect(!settled)
    }

    @Test("the bound sits under the grace and the settle")
    func boundsAreOrdered() {
        #expect(
            SwitchReconcile.bound < EventLoop.spaceSwitchCoalesceGrace
        )
        #expect(SwitchReconcile.bound < 0.6, "the settle's delay")
        #expect(
            SwitchReconcile.stragglerLimit <= KiwiCore.inFlightWindow
        )
    }
}
