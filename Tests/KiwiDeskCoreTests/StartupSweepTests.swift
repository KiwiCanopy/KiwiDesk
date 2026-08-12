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
/// reconcile then drives. The remaining unpinned link —
/// `start()` calling `scheduleStartupSweep()` — is carried as
/// an obligation in accessibility.md, because `start()` itself
/// is not test-drivable.
///
/// The await rides the sweep's real 1 s schedule; that cost is
/// the assertion's subject, not incidental sleep (tests.md).
@MainActor
@Suite("Startup sweep (#662/#672)")
struct StartupSweepTests {
    @MainActor
    private final class CountBox {
        var appSourceReads = 0
    }

    /// The whole scan in one turn. Production chunks it and
    /// hands the run loop back between chunks (`KiwiCore+Boot`,
    /// #801) — a suite has nothing to yield to, so it drains with
    /// no budget.
    private func runWholeScan(_ loop: EventLoop) {
        #expect(loop.beginScan())
        loop.scanChunk(budget: nil)
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
        loop.makeObserver = { _ in nil }
        loop.runningApplications = {
            box.appSourceReads += 1
            return []
        }
        runWholeScan(loop)
        defer { loop.stop() }
        let readsAfterStart = box.appSourceReads

        core.scheduleStartupSweep()
        await core.deferred.task(for: .startupSweep)?.value

        // reconcileAll consulted the app source again — the
        // sweep really reconciles, it does not merely fire.
        #expect(box.appSourceReads > readsAfterStart)
        // And the retile batch flag was lowered on the way out,
        // so steady-state events retile again (#672).
        #expect(!core.defersEventRetiles)
    }
}
