import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The readiness phase (#802) and the driver that advances it
/// (#801).
///
/// `BootScanChunkTests` pins the queue; this pins what a surface
/// reads off it — that the phase is published as the chunks land,
/// that an unchanged phase costs nothing, and that the driver
/// actually comes back after handing the run loop over. The one
/// link no test can drive is `start()` itself (it arms the real
/// machine seams), so the three publish sites are needled in
/// `BootPhaseWiringTests` — the `scheduleStartupSweep` precedent.
@MainActor
@Suite("Boot readiness phase (#802)")
struct BootPhaseTests {
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
        var phases: [BootPhase] = []
        var lines: [String] = []
        var windowQueries = 0
        var clock = ContinuousClock.now
        var step: Duration = .milliseconds(10)
    }

    private func makeCore(
        apps: Int
    ) -> (core: KiwiCore, box: Box) {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-boot-\(UUID().uuidString)"
                )
        )
        let box = Box()
        core.onLog = { box.lines.append($0) }
        core.onBootPhaseChange = { box.phases.append($0) }
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 900)
        }
        let loop = core.eventLoop
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.applyAXMessagingTimeout = { _ in }
        loop.activationPolicy = { _ in .regular }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.visiblePIDs = { [] }
        loop.axWindows = { _ in
            box.windowQueries += 1
            return []
        }
        loop.runningApplications = {
            (0..<apps).map { index in
                RunningApp(
                    pid: pid_t(670_000 + index),
                    activationPolicy: .regular,
                    ref: AppRef(
                        bundleID: "test.kiwi.boot\(index)",
                        name: "Boot \(index)"
                    )
                )
            }
        }
        loop.monotonicNow = {
            box.clock = box.clock.advanced(by: box.step)
            return box.clock
        }
        return (core, box)
    }

    // MARK: - The phase itself

    @Test("an unchanged phase is not republished")
    func anUnchangedPhaseIsNotRepublished() {
        var published: [BootPhase] = []
        let run = BootRun()
        run.onPhaseChange = { published.append($0) }

        run.publish(.scanning(scanned: 3, total: 9))
        run.publish(.scanning(scanned: 3, total: 9))
        run.publish(.scanning(scanned: 4, total: 9))
        run.publish(.ready)
        run.publish(.ready)

        // A chunk that attaches nothing still publishes, and the
        // GUI redraws its icon off this seam — so an unchanged
        // phase has to be dropped here rather than at every
        // listener.
        #expect(
            published == [
                .scanning(scanned: 3, total: 9),
                .scanning(scanned: 4, total: 9),
                .ready,
            ]
        )
        #expect(run.phase == .ready)
    }

    @Test("only scanning counts as starting")
    func onlyScanningIsStarting() {
        // One predicate for the mark, the count row and the
        // greyed rows — three surfaces that must agree on when
        // boot is over.
        #expect(BootPhase.scanning(scanned: 0, total: 4).isStarting)
        #expect(!BootPhase.idle.isStarting)
        #expect(!BootPhase.ready.isStarting)
    }

    // MARK: - The driver

    @Test("the driver publishes progress and comes back")
    func theDriverPublishesProgressAndReturns() async {
        let (core, box) = makeCore(apps: 5)
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        #expect(core.eventLoop.beginScan())
        var finished = false

        core.driveChunkedPass(
            onChunk: {
                core.boot.publish(
                    .scanning(
                        scanned: $0.scanned,
                        total: $0.total
                    )
                )
            },
            onFinish: { finished = true }
        )

        // The first chunk left work behind — which is the whole
        // point — so the pass is only finished after the
        // continuations it scheduled have run.
        #expect(!finished)
        var turns = 0
        while !finished, turns < 20 {
            await core.deferred.task(for: .bootScan)?.value
            turns += 1
        }
        #expect(finished)
        #expect(turns > 0)
        // Every chunk with work behind it reached the seam, in
        // order and short of the total: the finishing chunk calls
        // the epilogue INSTEAD of publishing, so the count never
        // announces a completion the phase is about to announce
        // itself.
        let counts = box.phases.compactMap { phase -> Int? in
            guard case .scanning(let scanned, _) = phase else {
                return nil
            }
            return scanned
        }
        #expect(counts == counts.sorted())
        #expect(!counts.isEmpty)
        #expect(counts.allSatisfy { $0 < 5 })
    }

    @Test("a deferred app completes one per turn")
    func aDeferredAppCompletesOnePerTurn() async {
        let (core, box) = makeCore(apps: 0)
        defer {
            core.deferred.cancelAll()
            core.eventLoop.stop()
        }
        #expect(core.eventLoop.beginScan())
        core.eventLoop.scanChunk(budget: nil)
        let first: pid_t = 671_001
        let second: pid_t = 671_002
        for pid in [first, second] {
            core.eventLoop.attach(
                pid: pid,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "slow", name: "Slow"),
                scanWindowsAtAttach: false
            )
        }
        box.windowQueries = 0

        core.drainDeferredBootApps([
            (first, AppRef(bundleID: "slow.one", name: "One")),
            (second, AppRef(bundleID: "slow.two", name: "Two")),
        ])
        await core.deferred.task(for: .deferredBootApps)?.value

        // One app per turn: completing them back to back would
        // re-block the run loop the boot just freed.
        #expect(box.windowQueries == 1)
        #expect(
            box.lines.contains {
                $0.hasPrefix("deferred app: slow.one")
            }
        )
        #expect(
            !box.lines.contains {
                $0.hasPrefix("deferred app: slow.two")
            }
        )

        await core.deferred.task(for: .deferredBootApps)?.value

        #expect(box.windowQueries == 2)
        #expect(
            box.lines.contains {
                $0.hasPrefix("deferred app: slow.two")
            }
        )
    }
}
