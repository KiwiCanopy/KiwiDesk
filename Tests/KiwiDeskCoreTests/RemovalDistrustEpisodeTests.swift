import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The removal-distrust EPISODE (#1157): the per-window ledger,
/// its bounded re-queue (`EventLoop.removalRecheckCap`), the
/// one-line-per-episode log, convergence once the census drops a
/// true close, and the bootstrap wiring that arms the
/// `.removalRecheck` one-shot. The gate's arms — who is checked,
/// who is exempt — are `RemovalDistrustTests`', split at the
/// tests.md file ceiling; the harness is a per-file copy by that
/// file's convention.
@MainActor
@Suite("Removal distrust episodes and wiring")
struct RemovalDistrustEpisodeTests {
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

    private let pid: pid_t = 909_911
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

    @Test("a ridden queue does not spend the episode's cap")
    func riddenQueueDoesNotSpendTheCap() {
        // A refusal landing while the one-shot is already armed
        // rides that deadline; only a fresh arm — a full-delay
        // pass — counts against `removalRecheckCap`, or an
        // incidental reconcile could quiet the episode without
        // it ever getting one.
        let (loop, box) = makeLoop()
        loop.elements[pid] = [WindowID(12): dummyElement]
        box.listed = []
        box.census = [pid: [WindowID(12)]]
        loop.reconcile(pid: pid, app: ref)
        // Un-drained: the next refusal rides the armed one-shot.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.recheckFires == 1)
        #expect(loop.drainPendingRemovalRecheck() == [pid])
        // The ride spent nothing, so a second full-delay arm is
        // still owed…
        loop.reconcile(pid: pid, app: ref)
        #expect(box.recheckFires == 2)
        #expect(loop.drainPendingRemovalRecheck() == [pid])
        // …and only then is the episode out of arms.
        loop.reconcile(pid: pid, app: ref)
        #expect(box.recheckFires == 2)
        #expect(loop.pendingRemovalRecheck.isEmpty)
        #expect(distrustLines(box) == 1)
    }
}
