import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// **What waits on an off-main reconcile, and which focus report
/// stands** (#1930). One list read is outstanding per app and
/// answers only what was owed when it began; a focus report that
/// lands late delivers only while its app emitted none newer.
/// The read work is captured and pumped by hand, in whatever
/// order a test needs: the list read is queued ahead of the
/// activation's focus read.
@Suite("Reconcile off main: debts and report order (#1930)")
@MainActor
struct ReconcileOffMainDebtTests {
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
        var focused: [WindowID] = []
        var destroyed: [WindowID] = []
        var logs: [String] = []
        var listReads = 0
        var focusReads = 0
        /// The ids the AX list answers; empty destroys window 21.
        var listed: [WindowID] = []
        var work: [@Sendable () -> Void] = []
        var dispatched: [pid_t] = []
        var focus: WindowID?

        func drain() {
            while !work.isEmpty { work.removeFirst()() }
        }
        /// Runs the queued read at `index` ahead of the others.
        func run(_ index: Int) {
            guard index < work.count else {
                Issue.record("no queued read at \(index)")
                return
            }
            work.remove(at: index)()
        }
    }

    private let pid: pid_t = 717_717
    private let other: pid_t = 616_616
    private let id = WindowID(21)
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.offmain", name: "OffMain")
    }

    private func app(_ pid: pid_t) -> RunningApp {
        RunningApp(pid: pid, activationPolicy: .regular, ref: ref)
    }

    /// A loop observing `pid` with window 21 tracked and the AX
    /// list answering NOTHING unless a test lists it — so a
    /// reconcile that ran destroys it, which is how a test sees
    /// whether it ran yet.
    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.logs.append($0) }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.activationPolicy = { _ in .regular }
        loop.onScreenNormalWindowIDs = { [:] }
        loop.appIsHidden = { _ in false }
        loop.frontmostPID = { nil }
        loop.shadows.focusedWindow = { _ in
            MainActor.assumeIsolated {
                box.focusReads += 1
                return box.focus
            }
        }
        let dummy = AXUIElementCreateApplication(pid)
        loop.axWindows = { _ in
            let count = MainActor.assumeIsolated {
                box.listReads += 1
                return box.listed.count
            }
            return Array(repeating: dummy, count: count)
        }
        loop.resolveWindowID = { _ in
            MainActor.assumeIsolated { box.listed.first }
        }
        loop.axReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.axReads.reader = { _ in
            CGRect(x: 0, y: 0, width: 640, height: 480)
        }
        loop.axReads.dispatchOverride = { pid, work in
            box.dispatched.append(pid)
            box.work.append(work)
        }
        loop.onEvent = { event in
            switch event {
            case .windowFocused(let id): box.focused.append(id)
            case .windowDestroyed(let id, _): box.destroyed.append(id)
            default: break
            }
        }
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.elements[pid] = [id: AXUIElementCreateApplication(pid)]
        return (loop, box)
    }

    @Test("a request mid-read is owed by the next read")
    func midReadRequestTakesTheNextRead() {
        let (loop, box) = makeLoop()
        var answered: [String] = []
        loop.reconcileOffMain(pid: pid, app: ref) { answered.append("a") }
        loop.reconcileOffMain(pid: pid, app: ref) { answered.append("b") }
        loop.reconcileOffMain(pid: pid, app: ref) { answered.append("c") }
        #expect(box.work.count == 1)
        box.run(0)
        #expect(answered == ["a"])
        #expect(box.listReads == 1)
        // b and c arrived mid-read: one more read answers both.
        #expect(box.work.count == 1)
        box.run(0)
        #expect(answered == ["a", "b", "c"])
        #expect(box.listReads == 2)
        #expect(box.work.isEmpty)
    }

    @Test("an untracked activation focus waits on the read asked")
    func untrackedFocusJoinsThePendingRead() {
        let (loop, box) = makeLoop()
        let late = WindowID(31)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        #expect(box.work.count == 2)
        // The focus read answers first: the window is untracked,
        // so the report waits on the list read already queued.
        box.run(1)
        #expect(box.focused.isEmpty)
        #expect(box.work.count == 1, "a second list read was asked")
        // The reconcile adopts it (by hand: the fixture cannot
        // track a fabricated element) and the report lands.
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.listed = [late]
        box.run(0)
        #expect(box.focused == [late])
        #expect(box.listReads == 1)
    }

    @Test("a newer report drops a waiting one")
    func newerReportDropsTheWaitingOne() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        let late = WindowID(32)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        box.run(1)
        // The user focuses tracked window 21 while the report for
        // the untracked one waits on the list read, and that newer
        // report lands first.
        loop.handleFocusedWindowChanged(
            AXUIElementCreateApplication(pid),
            pid: pid,
            app: ref
        )
        box.run(1)
        #expect(box.focused == [id])
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.listed = [id, late]
        box.drain()
        #expect(box.focused == [id], "reported \(box.focused)")
    }

    @Test("a waiting report with no newer one still lands")
    func waitingReportLandsAlone() {
        // The negative control for the generation drop above.
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        let late = WindowID(33)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        box.run(1)
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.listed = [id, late]
        box.drain()
        #expect(box.focused == [late])
    }

    @Test("a newer report that was dropped supersedes nothing")
    func droppedNewerReportSupersedesNothing() {
        let (loop, box) = makeLoop()
        loop.lastActivePid = pid
        box.focus = id
        box.listed = [id]
        loop.appActivated(app(pid), launchedAt: nil)
        // A focus change naming no window (a dead element) asks
        // after the activation and reports nothing.
        loop.resolveWindowID = { _ in nil }
        loop.handleFocusedWindowChanged(
            AXUIElementCreateApplication(other),
            pid: pid,
            app: ref
        )
        loop.resolveWindowID = { _ in
            MainActor.assumeIsolated { box.listed.first }
        }
        box.drain()
        #expect(box.focused == [id], "reported \(box.focused)")
    }

    @Test("an untracked focus joins the read parked behind one")
    func untrackedFocusJoinsTheParkedRead() {
        let (loop, box) = makeLoop()
        // A read is already in flight when the app activates, so
        // the activation's own reconcile is parked behind it.
        loop.reconcileOffMain(pid: pid, app: ref)
        let late = WindowID(34)
        box.focus = late
        loop.appActivated(app(pid), launchedAt: nil)
        #expect(box.work.count == 2)
        box.run(1)
        // The read that began first answers nothing it was not
        // asked before it began.
        box.run(0)
        #expect(box.focused.isEmpty, "judged by the earlier read")
        #expect(box.work.count == 1)
        loop.elements[pid]?[late] = AXUIElementCreateApplication(pid)
        box.listed = [late]
        box.run(0)
        #expect(box.focused == [late])
    }

    @Test("a read from before a stop pays nothing after it")
    func staleReadPaysNothing() {
        let (loop, box) = makeLoop()
        var answered: [String] = []
        loop.reconcileOffMain(pid: pid, app: ref) { answered.append("a") }
        loop.offMain = OffMainReconcile()
        loop.reconcileOffMain(pid: pid, app: ref) { answered.append("b") }
        box.drain()
        #expect(answered == ["b"])
        #expect(box.listReads == 2)
    }

    @Test("an app KiwiDesk does not observe is never read")
    func unobservedAppIsNeverRead() {
        let (loop, box) = makeLoop()
        let stranger: pid_t = 515_515
        loop.lastActivePid = stranger
        loop.appActivated(app(pid), launchedAt: nil)
        box.drain()
        #expect(!box.dispatched.contains(stranger))
        #expect(box.listReads == 1)
    }
}
