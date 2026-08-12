import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-app boot budget (#803).
///
/// One app's reconcile measured 5011 ms on the field session that
/// opened #801, against a 4826 ms scan for the other 108 apps
/// together. Chunking cannot divide that: one app's AX work is
/// indivisible, so without a bound the menu is dead for five
/// seconds inside whichever chunk owns the outlier. Past the
/// budget its remaining work is dropped and completed after boot.
///
/// Every claim rides the injected clock seam — the AX fakes
/// answer instantly, so nothing here spends real time (tests.md
/// bans a timing wait).
@MainActor
@Suite("Per-app boot budget (#803)")
struct BootAppBudgetTests {
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

    @MainActor
    private final class Box {
        var lines: [String] = []
        var windowQueries = 0
        var destroyed: [WindowID] = []
        var clock = ContinuousClock.now
        /// How much the clock jumps per read — assigned per test,
        /// so one fixture covers a slow app and a fast one.
        var step: Duration = .milliseconds(1)

        var observerInstalls = 0

        var deferrals: [String] {
            lines.filter { $0.hasPrefix("boot budget:") }
        }
    }

    private let pids: [pid_t] = [660_001, 660_002]

    private func ref(_ index: Int) -> AppRef {
        AppRef(
            bundleID: "test.kiwi.slow\(index)",
            name: "Slow \(index)"
        )
    }

    private func makeLoop() -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.lines.append($0) }
        loop.registersWorkspaceObservers = false
        loop.applyAXMessagingTimeout = { _ in }
        loop.activationPolicy = { _ in .regular }
        loop.makeObserver = { _ in
            // The observer install is itself AX work — this is
            // where the measured outlier spends its whole cost —
            // so the fake charges the clock for it.
            box.observerInstalls += 1
            _ = box.clock
            return FakeObserver()
        }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        // Visible per the prefilter: the scan does this app's
        // window query and warmup at attach, which is the work a
        // budget bounds.
        loop.visiblePIDs = { Set(self.pids) }
        loop.runningApplications = {
            self.pids.enumerated().map { index, pid in
                RunningApp(
                    pid: pid,
                    activationPolicy: .regular,
                    ref: self.ref(index + 1)
                )
            }
        }
        loop.onEvent = { event in
            if case .windowDestroyed(let id, _) = event {
                box.destroyed.append(id)
            }
        }
        loop.monotonicNow = {
            box.clock = box.clock.advanced(by: box.step)
            return box.clock
        }
        return (loop, box)
    }

    @Test("a slow app is deferred and the pass goes on")
    func aSlowAppIsDeferredAndThePassGoesOn() {
        let (loop, box) = makeLoop()
        // 600 ms per clock read: past `bootAppBudget` (500 ms)
        // on the first checkpoint, which is the shape of an app
        // that spent a whole AX messaging timeout on one call.
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        defer { loop.stop() }

        loop.scanChunk(budget: nil)

        // Both apps were visited and both kept their observer —
        // deferral drops the app's remaining WORK, never its
        // event stream, or its windows would never arrive at all.
        #expect(loop.observes(pid: pids[0]))
        #expect(loop.observes(pid: pids[1]))
        #expect(box.deferrals.count == 2)
        // Named, because the outlier stays diagnosable from a
        // field syslog with no Instruments attached (#672).
        #expect(
            box.deferrals.contains {
                $0.contains("test.kiwi.slow1")
            }
        )
        // And recorded for the post-boot completion, exactly
        // once: the driver takes them and clears the ledger.
        let deferred = loop.takeDeferredBootApps()
        #expect(Set(deferred.keys) == Set(pids))
        #expect(loop.takeDeferredBootApps().isEmpty)
    }

    @Test("a healthy app is never deferred")
    func aHealthyAppIsNeverDeferred() {
        let (loop, box) = makeLoop()
        // 40 ms per read: an Electron-class lazy answer
        // (100–300 ms, accessibility.md) still fits the budget,
        // and a watchdog that fires on healthy work is worse
        // than none.
        box.step = .milliseconds(40)
        #expect(loop.beginScan())
        defer { loop.stop() }

        loop.scanChunk(budget: nil)

        #expect(box.deferrals.isEmpty)
        #expect(loop.takeDeferredBootApps().isEmpty)
        // The work it bounds actually ran: one window query per
        // visible app.
        #expect(box.windowQueries == pids.count)
    }

    /// The budget is scoped to a queued STEP, not to a pass being
    /// open — and chunking is exactly what made the difference
    /// observable: the run loop is live between chunks, so an app
    /// launching, an activation reconcile or a Desktop-switch
    /// `reconcileAll` lands *inside* an open pass. Budgeting those
    /// would cut short work no one asked to be fast (architect and
    /// code review, 2026-08-12).
    @Test("work the OS drove is unbudgeted, pass open or not")
    func onlyQueuedStepsAreBudgeted() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)
        _ = loop.takeDeferredBootApps()
        box.lines = []

        // After the pass closed …
        loop.attach(
            pid: 660_003,
            activationPolicy: .regular,
            ref: ref(3),
            scanWindowsAtAttach: true
        )
        #expect(box.deferrals.isEmpty)

        // … and, the case only chunking creates, BETWEEN two
        // chunks of a pass that is still open.
        #expect(loop.beginSweep())
        loop.attach(
            pid: 660_004,
            activationPolicy: .regular,
            ref: ref(4),
            scanWindowsAtAttach: true
        )
        #expect(box.deferrals.isEmpty)
        #expect(loop.takeDeferredBootApps().isEmpty)
    }

    /// The app that opened #803 owns no normal window, so the
    /// prefilter says "windowless" and `attach` used to return
    /// before any budget existed — its 4004 ms was spent
    /// installing the observer, four AX calls each hitting the
    /// ~1 s messaging timeout, and NO `boot budget:` line was
    /// logged for it on the owner's device (2026-08-12). The
    /// budget therefore opens before the install.
    @Test("an observer install that blows the budget defers")
    func theObserverInstallIsBudgeted() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        defer { loop.stop() }
        // Windowless per the prefilter: nothing below the early
        // return would ever run for these apps.
        loop.visiblePIDs = { [] }

        loop.scanChunk(budget: nil)

        #expect(box.deferrals.count == 2)
        // Attached even so — the observer is installed, so the
        // app's windows still arrive by event. Deferral drops the
        // WORK, never the event stream.
        #expect(loop.observes(pid: pids[0]))
    }

    /// One app's cost is one blocking call, which no budget can
    /// interrupt — so the same app is not asked again this boot.
    /// The device log paid it three times: 4004 ms at attach,
    /// then 5008 ms in the sweep, then again in the
    /// monitor-change reload.
    @Test("a deferred app is skipped by later passes this boot")
    func aDeferredAppIsSkippedLater() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)
        #expect(box.deferrals.count == 2)
        // The boot tail drains — and production ALWAYS drains
        // before the sweep opens, a second earlier. Clearing the
        // skip list on that take handed the sweep an empty list
        // and it paid the outlier again, which is the saving this
        // mechanism exists for (code review, 2026-08-12).
        #expect(!loop.takeDeferredBootApps().isEmpty)
        let queriesAfterScan = box.windowQueries
        let installsAfterScan = box.observerInstalls

        // The sweep queues both apps again …
        #expect(loop.beginSweep())
        loop.scanChunk(budget: nil)

        // … and touches neither: no window snapshot, no AX at
        // all, for an app already given up on.
        #expect(box.windowQueries == queriesAfterScan)
        #expect(box.observerInstalls == installsAfterScan)
        // The sweep found nothing new to defer, the scan's
        // deferrals having already been taken by the tail.
        #expect(loop.takeDeferredBootApps().isEmpty)
    }

    /// The skip list is a fact about ONE boot: a later launch
    /// must give the app its chance again, or an app that was
    /// merely busy once is written off for the session.
    @Test("a new boot clears the skip list")
    func aNewBootClearsTheSkipList() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
        #expect(box.deferrals.count == 2)
        loop.stop()

        // A fresh boot, with the app answering promptly now.
        box.step = .milliseconds(1)
        let queriesAfterFirstBoot = box.windowQueries
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)

        #expect(box.windowQueries > queriesAfterFirstBoot)
        #expect(box.deferrals.count == 2)
    }

    /// The dangerous half of the abort, and the reason the
    /// reconcile checkpoints return where they do: the sweep at
    /// the end of `reconcile` derives destroys from the live list
    /// it just read. Returning mid-read WITH the sweep would
    /// untrack every window the abort never reached — the app
    /// would lose its layout slots for being slow.
    @Test("a spent budget aborts a reconcile before its sweep")
    func aSpentBudgetAbortsBeforeTheSweep() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(1)
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)
        let tracked = WindowID(9_001)
        loop.elements[pids[0]] = [
            tracked: AXUIElementCreateApplication(pids[0])
        ]

        // A queued sweep step, with the clock spending the budget
        // inside it: the reconcile drops out early.
        box.step = .milliseconds(600)
        #expect(loop.beginSweep())
        loop.scanChunk(budget: nil)

        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pids[0]]?[tracked] != nil)

        // The control arm — the same reconcile, the same empty
        // window list, driven directly so no budget applies — DOES
        // sweep. That is what makes the assertion above a claim
        // about the abort rather than about the fixture.
        loop.reconcile(pid: pids[0], app: ref(1))

        #expect(box.destroyed == [tracked])
        #expect(loop.elements[pids[0]]?[tracked] == nil)
    }

    /// The sweep budgets exactly as the scan does, so it owes the
    /// same completion: a ledger only the boot tail took would
    /// leave a sweep-deferred app sitting untaken until `stop()`
    /// discarded it — abandoned to #675's heal, which is the
    /// outcome deferral exists to spare it (code review,
    /// 2026-08-12).
    @Test("the sweep's deferrals are recorded for completion")
    func theSweepAlsoDefers() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(1)
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)
        _ = loop.takeDeferredBootApps()

        box.step = .milliseconds(600)
        #expect(loop.beginSweep())
        loop.scanChunk(budget: nil)

        #expect(!box.deferrals.isEmpty)
        #expect(!loop.takeDeferredBootApps().isEmpty)
    }
}
