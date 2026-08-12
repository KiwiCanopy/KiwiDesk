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
        loop.makeObserver = { _ in FakeObserver() }
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
        loop.bootScan.now = {
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

    @Test("no budget is spent outside a chunked pass")
    func noBudgetOutsideAPass() {
        let (loop, box) = makeLoop()
        box.step = .milliseconds(600)
        #expect(loop.beginScan())
        defer { loop.stop() }
        loop.scanChunk(budget: nil)
        _ = loop.takeDeferredBootApps()
        box.lines = []

        // An event-driven attach — an app launched while the user
        // works — must never be cut short: only boot trades
        // completeness for latency.
        loop.attach(
            pid: 660_003,
            activationPolicy: .regular,
            ref: ref(3),
            scanWindowsAtAttach: true
        )

        #expect(box.deferrals.isEmpty)
        #expect(loop.takeDeferredBootApps().isEmpty)
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

        // Budgeted and spent: the reconcile drops out early.
        loop.bootScan.appBudget = EventLoop.bootAppBudget
        box.step = .milliseconds(600)
        loop.reconcile(pid: pids[0], app: ref(1))

        #expect(box.destroyed.isEmpty)
        #expect(loop.elements[pids[0]]?[tracked] != nil)

        // The control arm — same reconcile, same empty window
        // list, no budget — DOES sweep, which is what makes the
        // assertion above a claim about the abort rather than
        // about the fixture.
        loop.bootScan.appBudget = nil
        box.step = .milliseconds(1)
        loop.reconcile(pid: pids[0], app: ref(1))

        #expect(box.destroyed == [tracked])
        #expect(loop.elements[pids[0]]?[tracked] == nil)
    }
}
