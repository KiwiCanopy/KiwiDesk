import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The windowless-app warmup skip's safety contract (#662).
///
/// The boot scan may skip the expensive AX warmup for an app the
/// WindowServer reports windowless — that skip is safe *only*
/// because a following reconcile warms whatever was skipped.
/// This suite pins the funnel halves of that promise: the skip
/// gate itself, the reconcile-warms retry, the pre-start attach
/// inertness, and the `reconcileAll` scan dedup. What it cannot
/// see is `start()` still *calling* `scheduleStartupSweep()` —
/// `StartupSweepTests` pins the scheduled task's reconcile, and
/// `StartupSweepWiringTests` needles the tail's call itself
/// (#836, which made a second skip rest on it). Everything
/// here drives the funnels through the injected machine seams
/// (tests.md); no real app, observer, or AX call is touched.
@MainActor
@Suite("Windowless-app warmup skip (#662)")
struct StartupWarmupSkipTests {
    /// Inert healthy observer: attach installs it, nothing
    /// fires, registration never needs repair (#675 — health is
    /// stated, never defaulted).
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

    /// A loop whose machine seams are fakes, plus the write log
    /// the assertions read. The fake app answers the EUI read
    /// with `false` (an Electron shape: answers, tree cold), so
    /// a warmup is visible as the EUI-on write. `started: true`
    /// drives the real `start()` (empty app list, no workspace
    /// observers) rather than poking `isRunning` directly.
    private func makeLoop(
        started: Bool = true,
        euiReads: @escaping @MainActor (pid_t) -> Bool? = {
            _ in false
        }
    ) -> (
        loop: EventLoop,
        euiWrites: @MainActor () -> [Bool],
        manualWrites: @MainActor () -> Int,
        windowQueries: @MainActor () -> Int
    ) {
        let loop = EventLoop()
        let box = WriteBox()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.runningApplications = { [] }
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = euiReads
        loop.writeEnhancedUI = { _, on in
            box.euiWrites.append(on)
        }
        loop.writeManualAX = { _, _ in box.manualWrites += 1 }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        loop.activationPolicy = { _ in .regular }
        if started {
            runWholeScan(loop)
        }
        return (
            loop,
            { box.euiWrites },
            { box.manualWrites },
            { box.windowQueries }
        )
    }

    @MainActor
    private final class WriteBox {
        var euiWrites: [Bool] = []
        var manualWrites = 0
        var windowQueries = 0
    }

    private let pid: pid_t = 424_242
    private var ref: AppRef {
        AppRef(bundleID: "test.kiwi.cold", name: "Cold")
    }

    /// The whole scan in one turn. Production chunks it and
    /// hands the run loop back between chunks (`KiwiCore+Boot`,
    /// #801) — a suite has nothing to yield to, so it drains with
    /// no budget.
    private func runWholeScan(_ loop: EventLoop) {
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
    }

    @Test("a skipped app is warmed by the following reconcile")
    func skippedAppIsWarmedByReconcile() {
        let (loop, euiWrites, _, windowQueries) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        // The skip half: attached (observer installed), but no
        // window query and no warmup ran.
        #expect(loop.observes(pid: pid))
        #expect(windowQueries() == 0)
        #expect(euiWrites().isEmpty)
        // The promise half: the next reconcile of the attached
        // regular app warms it — and the attach + reconcile
        // pair cost exactly one window snapshot, which is the
        // #672 scan dedup's mechanism.
        loop.reconcile(pid: pid, app: ref)
        #expect(euiWrites() == [true])
        #expect(windowQueries() == 1)
    }

    @Test("a visible app is warmed at attach, not deferred")
    func visibleAppWarmsAtAttach() {
        let (loop, euiWrites, _, _) = makeLoop()
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: true
        )
        #expect(euiWrites() == [true])
    }

    @Test("the Chromium warmup fires once across reconciles")
    func chromiumWarmupIsSetOnce() {
        // Chromium never answers the EUI read (#360): the warm
        // is the one-time AXManualAccessibility write.
        let (loop, euiWrites, manualWrites, _) = makeLoop(
            euiReads: { _ in nil }
        )
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: false
        )
        loop.reconcile(pid: pid, app: ref)
        loop.reconcile(pid: pid, app: ref)
        #expect(manualWrites() == 1)
        #expect(euiWrites().isEmpty)
    }

    @Test("reconcileAll scans a newly attached app once (#672)")
    func reconcileAllScansOnce() {
        // The old shape scanned every app twice on one turn:
        // attach took a window snapshot and the reconcile right
        // after took another. reconcileAll's sync loop now
        // defers the scan to its own reconcile loop
        // (scanWindowsAtAttach: false) — this is the wiring
        // pin; the deferral mechanism itself is asserted above.
        let (loop, euiWrites, _, windowQueries) = makeLoop()
        let app = RunningApp(
            pid: pid,
            activationPolicy: .regular,
            ref: ref
        )
        loop.runningApplications = { [app] }
        loop.reconcileAll()
        #expect(loop.observes(pid: pid))
        #expect(windowQueries() == 1)
        #expect(euiWrites() == [true])
    }

    @Test("attach before start is inert (#672)")
    func attachBeforeStartIsInert() {
        // The ordering half of the boot fix: loadConfig's
        // pre-start reconcileAll must not attach anything, or
        // the scan's prefilter tests nothing — every app is
        // already attached and warmed eagerly by the time
        // start() runs.
        let (loop, euiWrites, _, windowQueries) = makeLoop(
            started: false
        )
        loop.attach(
            pid: pid,
            activationPolicy: .regular,
            ref: ref,
            scanWindowsAtAttach: true
        )
        #expect(!loop.observes(pid: pid))
        #expect(windowQueries() == 0)
        #expect(euiWrites().isEmpty)
    }
}
