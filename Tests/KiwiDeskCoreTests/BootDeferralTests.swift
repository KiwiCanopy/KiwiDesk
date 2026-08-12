import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What happens to an app AFTER a budget cuts it short (#803).
///
/// `BootAppBudgetTests` pins when the budget fires; this pins the
/// two ledgers behind it — the skip list that stops a later pass
/// paying the same blocking call, and the drain queue whose
/// completion is what makes deferral honest rather than
/// abandonment. Split from that suite at the §2.1 ceiling.
///
/// Every claim rides the injected clock seam — the AX fakes
/// answer instantly, so nothing here spends real time (tests.md
/// bans a timing wait).
@MainActor
@Suite("Boot deferral ledger (#803)")
struct BootDeferralTests {
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
    /// A launch that stopped mid-drain must not wedge the next
    /// one. "Is a chain running" is derived from the queue being
    /// non-empty, so a queue left behind reads as a live chain
    /// forever: every later launch appends, none schedules, and
    /// every deferred app is abandoned for the session (architect
    /// review, 2026-08-12).
    @Test("a queue left by a stopped launch does not wedge boot")
    func aStoppedDrainDoesNotWedgeTheNextBoot() {
        let (loop, _) = makeLoop()
        #expect(loop.beginScan())
        loop.bootScan.pendingDrain = [
            (pids[0], ref(1)), (pids[1], ref(2)),
        ]

        loop.stop()

        #expect(loop.bootScan.pendingDrain.isEmpty)
        #expect(loop.beginScan())
        defer { loop.stop() }
        #expect(loop.bootScan.pendingDrain.isEmpty)
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
