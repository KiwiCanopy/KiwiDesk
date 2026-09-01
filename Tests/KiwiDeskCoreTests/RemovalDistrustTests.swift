import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// A sweep removal distrusts one missing AX read while the
/// WindowServer still shows the window (#1157).
///
/// The defect this pins is #1157's: the sweep read a lazy-AX
/// app's transient under-report as a close. The gate refuses the
/// removal while the on-screen census still lists the window,
/// logs once per continuous-absence episode, and queues a
/// follow-up reconcile so a TRUE close still compositing at
/// sweep time converges.
///
/// Everything drives the funnels through the injected seams
/// (tests.md); no app is attached to or messaged for real. The
/// harness mirrors `HiddenAppWindowTests`' (per-file helpers are
/// the convention there).
@MainActor
@Suite("Removal distrust under AX under-reporting")
struct RemovalDistrustTests {
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
        var hidden = false
        /// What the app's AX window list reports.
        var listed: [WindowID] = []
        var cursor = 0
        /// What the WindowServer census reports, and how often
        /// it was asked — the hidden drop must never ask (#913).
        var census: [pid_t: Set<WindowID>] = [:]
        var censusReads = 0
        var recheckFires = 0
        var logs: [String] = []
        var hiddenEvents: [WindowID] = []
        var destroyed: [(id: WindowID, wasMinimized: Bool)] = []
    }

    private let pid: pid_t = 909_910
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.distrust", name: "Distrust")
    }

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
        loop.onScreenNormalWindowIDs = {
            box.censusReads += 1
            return box.census
        }
        loop.onRemovalDistrust = { box.recheckFires += 1 }
        // The under-reporting app answers with a PARTIAL list —
        // that is the whole defect — so the fake list must pair
        // each element with its id in order (the cursor).
        loop.axWindows = { _ in
            box.cursor = 0
            return box.listed.map { _ in self.dummyElement }
        }
        loop.resolveWindowID = { _ in
            defer { box.cursor += 1 }
            guard box.cursor < box.listed.count else { return nil }
            return box.listed[box.cursor]
        }
        loop.appIsHidden = { _ in box.hidden }
        loop.onEvent = { event in
            switch event {
            case .windowDestroyed(let id, let wasMinimized):
                box.destroyed.append(
                    (id: id, wasMinimized: wasMinimized)
                )
            case .windowHidden(let id):
                box.hiddenEvents.append(id)
            default:
                break
            }
        }
        // `attach` refuses before `start()` (#672); a reconcile
        // without an observer detaches instead of sweeping, so
        // every claim here would pass for the wrong reason on an
        // unstarted loop.
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        return (loop, box)
    }

    /// An inert AX value for seeding `elements` directly.
    private var dummyElement: AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    private func distrustLines(_ box: Box) -> Int {
        box.logs.count { $0.hasPrefix("close distrust:") }
    }

    @Test("an under-reported on-screen window keeps its slot")
    func underReportedWindowIsKept() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = [WindowID(11)]
        box.census = [pid: [WindowID(11), WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pid]?[WindowID(12)] != nil)
        // The refusal owes its convergence pass: the pid queued
        // and the distrust's own one-shot armed, so a true close
        // still compositing at sweep time is re-read rather than
        // waiting for the next incidental reconcile.
        #expect(loop.pendingRemovalRecheck.contains(pid))
        #expect(box.recheckFires == 1)
        #expect(distrustLines(box) == 1)
    }

    @Test("an unlisted vanished window is removed as before")
    func unlistedVanishedWindowIsRemoved() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = [WindowID(11)]
        box.census = [pid: [WindowID(11)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(box.destroyed.map(\.wasMinimized) == [false])
        #expect(box.recheckFires == 0)
    }

    @Test("an episode re-queues once, logs once, then goes quiet")
    func episodeReQueueIsBounded() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.drainPendingRemovalRecheck() == [pid])
        // The follow-up pass still refuses: it re-queues — the
        // first queue may have ridden a part-spent deadline, so
        // the episode is owed one full-delay pass — but never
        // re-logs.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.recheckFires == 2)
        #expect(loop.drainPendingRemovalRecheck() == [pid])
        // Past the cap the episode goes quiet: a permanently
        // mismatched app costs a bounded number of follow-ups,
        // never a per-delay reconcile loop for the session.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(box.recheckFires == 2)
        #expect(loop.pendingRemovalRecheck.isEmpty)
        #expect(distrustLines(box) == 1)
    }

    @Test("a window back in the AX list re-opens the episode")
    func relistingEndsTheEpisode() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        _ = loop.drainPendingRemovalRecheck()
        // The app answers properly again…
        box.listed = [WindowID(12)]
        loop.reconcile(pid: pid, app: ref)
        #expect(loop.removalDistrusted.isEmpty)
        // …so the next under-report is a fresh episode: refused,
        // logged and queued anew.
        box.listed = []
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        #expect(box.recheckFires == 2)
        #expect(distrustLines(box) == 2)
    }

    @Test("a true close converges once the census drops it")
    func trueCloseConverges() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // The compositor finishes tearing the window down; the
        // queued follow-up's reconcile now removes it.
        box.census = [:]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(loop.removalDistrusted.isEmpty)
    }

    @Test("the hidden drop never consults the census")
    func hiddenDropSkipsTheGate() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = [WindowID(11), WindowID(12)]
        box.hidden = true
        // Contrived on purpose: even a census claiming both
        // windows must not turn the hide into a refusal — the
        // hide is a total answer about the app (#913), and its
        // path never pays the read.
        box.census = [pid: [WindowID(11), WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.censusReads == 0)
        #expect(
            box.hiddenEvents.sorted { $0.raw < $1.raw }
                == [WindowID(11), WindowID(12)]
        )
        #expect(box.destroyed.isEmpty)
    }

    @Test("a minimized vanish skips the gate")
    func minimizedVanishSkipsTheGate() {
        // Driven at the sweep: `reconcile` reads minimized off
        // live AX, which a fake element cannot answer. A parked
        // window is not census-listed in reality; the contrived
        // listing proves the gate defers to the minimize verdict
        // rather than to the census.
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.census = [pid: [WindowID(12)]]
        loop.reconcileTabsAndSweep(
            pid: pid,
            app: ref,
            appeared: [],
            live: [],
            minimized: [WindowID(12)],
            coalesceTabs: false
        )
        #expect(box.censusReads == 0)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(box.destroyed.map(\.wasMinimized) == [true])
    }

    @Test("one census read serves every candidate in a sweep")
    func oneCensusReadPerSweep() {
        let (loop, box) = makeLoop()
        loop.elements[pid] = [
            WindowID(11): dummyElement,
            WindowID(12): dummyElement,
        ]
        box.listed = []
        box.census = [pid: [WindowID(11), WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        #expect(box.destroyed.isEmpty)
        // The gate's cost bound: a sweep pays the WindowServer
        // once however many candidates it checks.
        #expect(box.censusReads == 1)
    }

    @Test("the gate stands down inside the Desktop-switch grace")
    func switchGraceStandsTheGateDown() {
        // During the grace the census double-exposes both
        // Desktops (#1023), so a departed window would be
        // refused on every switch; removals keep the pre-gate
        // behavior there.
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.lastDesktopChange = Date()
        loop.reconcile(pid: pid, app: ref)
        #expect(box.censusReads == 0)
        #expect(box.destroyed.map(\.id) == [WindowID(12)])
        #expect(box.recheckFires == 0)
    }

    @Test("a refusal arms the recheck one-shot on a live core")
    func refusalSchedulesTheRecheck() {
        // The bootstrap wiring, which no seam-driven test above
        // can see: deleting `onRemovalDistrust`'s assignment
        // leaves every other assertion green while the follow-up
        // silently never comes.
        let core = makeTestCore()
        core.eventLoop.refuseRemoval(
            WindowID(9),
            pid: 1,
            app: AppRef(bundleID: "test.kiwi.wire", name: "W")
        )
        #expect(core.deferred.isScheduled(.removalRecheck))
    }
}
