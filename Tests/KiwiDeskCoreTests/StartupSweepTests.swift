import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The startup sweep is the promise the boot prefilter's warmup
/// skip rests on (#662): a skipped app is warmed by a following
/// reconcile, and the sweep is the reconcile that is
/// *guaranteed* to come. This suite pins the scheduled task
/// actually running a `reconcileAll` (and lowering the retile
/// batch flag) — `StartupWarmupSkipTests` pins the funnel the
/// reconcile then drives. The third link — the boot tail
/// calling `scheduleStartupSweep()` at all — is not drivable
/// from here, since `start()` arms the real machine seams; it is
/// needled in `StartupSweepWiringTests` instead.
///
/// The await rides the sweep's real 1 s schedule; that cost is
/// the assertion's subject, not incidental sleep (tests.md).
@MainActor
@Suite("Startup sweep (#662/#672)")
struct StartupSweepTests {
    @MainActor
    private final class CountBox {
        var appSourceReads = 0
        var windowQueries = 0
    }

    /// The whole scan in one turn. Production chunks it and
    /// hands the run loop back between chunks (`KiwiCore+Boot`,
    /// #801) — a suite has nothing to yield to, so it drains with
    /// no budget.
    private func runWholeScan(_ loop: EventLoop) {
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
    }

    /// Inert healthy observer: attach installs it, nothing
    /// fires, registration never needs repair (#675).
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

    @Test("the scheduled sweep task runs a reconcileAll")
    func sweepTaskReconciles() async {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-sweep-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        let loop = core.eventLoop
        let box = CountBox()
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.activationPolicy = { _ in .regular }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        // A running app to reconcile. The fixture used to supply
        // NONE, so the sweep had zero steps and its claim was
        // observed by the queue merely being BUILT — gutting the
        // reconcile step left this green (guard-prover,
        // 2026-08-12).
        loop.runningApplications = {
            box.appSourceReads += 1
            return [
                RunningApp(
                    pid: 771_001,
                    activationPolicy: .regular,
                    ref: AppRef(
                        bundleID: "test.kiwi.sweep",
                        name: "Sweep"
                    )
                )
            ]
        }
        runWholeScan(loop)
        defer { loop.stop() }
        let readsAfterStart = box.appSourceReads
        let queriesAfterStart = box.windowQueries

        core.scheduleStartupSweep()
        await core.deferred.task(for: .startupSweep)?.value

        // The pass was opened — the app source was consulted to
        // build its queue …
        #expect(box.appSourceReads > readsAfterStart)
        // … and each queued step really reconciled its app: the
        // window snapshot is the reconcile's own AX call, and
        // nothing else in the sweep takes one.
        #expect(box.windowQueries > queriesAfterStart)
        // And the retile batch flag was lowered on the way out,
        // so steady-state events retile again (#672).
        #expect(!core.defersEventRetiles)
    }
}
