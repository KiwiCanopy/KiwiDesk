import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The chunked startup scan (#801).
///
/// The scan used to be one synchronous block, which is why the
/// menu-bar item and ⌃⌥K were dead for its whole length — boot
/// held the run loop they need. This suite pins what the split
/// bought and what it must not have broken: the queue is drained
/// across several calls, every app is still visited, and the
/// pass's epilogue (the summary line, the display publish) lands
/// exactly once at the end rather than per chunk.
///
/// Time comes from the injected clock seam, never a sleep
/// (tests.md's hang-guard rule): every AX fake answers instantly,
/// so a real budget could never be spent in a test.
@MainActor
@Suite("Chunked boot scan (#801)")
struct BootScanChunkTests {
    /// Inert healthy observer: attach installs it, nothing fires,
    /// registration never needs repair (#675 — health is stated,
    /// never defaulted).
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
        var attached: [pid_t] = []
        var displayPublishes = 0
        /// The fake clock's cursor, advanced on every read.
        var clock = ContinuousClock.now
        /// Pids whose observer creation fails — the fixture's way
        /// of making "visited" and "attached" different numbers.
        var refuses: Set<pid_t> = []

        var summaries: Int {
            lines.filter { $0.hasPrefix("startup scan:") }.count
        }
    }

    /// A loop whose every machine seam is a fake, and whose clock
    /// advances `step` per read. `step` is what decides how many
    /// apps fit in a chunk, so a suite states the cadence it wants
    /// instead of hoping the host is slow.
    private func makeLoop(
        apps: Int,
        step: Duration
    ) -> (loop: EventLoop, box: Box) {
        let loop = EventLoop()
        let box = Box()
        loop.onLog = { box.lines.append($0) }
        loop.registersWorkspaceObservers = false
        loop.applyAXMessagingTimeout = { _ in }
        loop.activationPolicy = { _ in .regular }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in [] }
        // Windowless per the prefilter: attach installs the
        // observer and skips the AX window query (#662), so the
        // only clock reads are the chunk's own.
        loop.visiblePIDs = { [] }
        loop.makeObserver = { pid in
            // A pid the caller marked unattachable answers nil,
            // exactly as `AXObserverCreate` does for a process
            // that will not have one.
            guard !box.refuses.contains(pid) else { return nil }
            box.attached.append(pid)
            return FakeObserver()
        }
        loop.runningApplications = {
            (1...max(apps, 1)).prefix(apps).map { index in
                RunningApp(
                    pid: pid_t(500_000 + index),
                    activationPolicy: .regular,
                    ref: AppRef(
                        bundleID: "test.kiwi.app\(index)",
                        name: "App \(index)"
                    )
                )
            }
        }
        loop.onEvent = { event in
            if case .displaysChanged = event {
                box.displayPublishes += 1
            }
        }
        loop.monotonicNow = {
            box.clock = box.clock.advanced(by: step)
            return box.clock
        }
        return (loop, box)
    }

    @Test("the queue drains across chunks, visiting every app")
    func everyAppIsVisitedAcrossChunks() {
        let (loop, box) = makeLoop(
            apps: 5,
            step: .milliseconds(10)
        )
        #expect(loop.beginScan())
        defer { loop.stop() }

        var chunks = 0
        var progress = loop.scanChunk(budget: .milliseconds(15))
        chunks += 1
        while !progress.finished {
            progress = loop.scanChunk(budget: .milliseconds(15))
            chunks += 1
        }

        // More than one chunk IS the fix: a single call would be
        // the synchronous scan again, whatever it is named.
        #expect(chunks > 1)
        #expect(box.attached.count == 5)
        #expect(progress.scanned == 5)
        #expect(progress.total == 5)
    }

    /// The honest count is apps VISITED of apps running, never
    /// attached-of-running: on the measured session 51 of 109 ever
    /// attach, so an attach tally stops at 47% and reads as a
    /// progress bar that stalled (`BootPhase` carries the
    /// ruling). Nothing separated the two readings until this
    /// fixture let an app refuse its observer — every fake
    /// attached, so both numbers were the same and the ruling was
    /// unguarded (guard-prover, 2026-08-12).
    @Test("the count is apps visited, not apps attached")
    func countsVisitedNotAttached() {
        let (loop, box) = makeLoop(apps: 4, step: .milliseconds(10))
        box.refuses = [500_002, 500_003]
        #expect(loop.beginScan())
        defer { loop.stop() }

        let progress = loop.scanChunk(budget: nil)

        // Two of the four attached; all four were visited, and
        // the count the menu row reads reaches its total.
        #expect(box.attached.count == 2)
        #expect(progress.scanned == 4)
        #expect(progress.total == 4)
        // The summary line keeps BOTH numbers — attaches of
        // running — which is what a field report is read against.
        #expect(
            box.lines.contains {
                $0.hasPrefix("startup scan: 2 apps attached of 4 ")
            }
        )
    }

    @Test("progress counts the apps visited so far")
    func progressCountsAppsVisited() {
        let (loop, _) = makeLoop(apps: 4, step: .milliseconds(10))
        #expect(loop.beginScan())
        defer { loop.stop() }

        let first = loop.scanChunk(budget: .milliseconds(15))
        #expect(!first.finished)
        #expect(first.total == 4)
        // The count the quick menu's row reads has to move, and
        // has to stay short of the total until the pass ends —
        // both halves of "honest" (#802).
        #expect(first.scanned >= 1)
        #expect(first.scanned < 4)
    }

    @Test("the summary and the display publish land once, last")
    func epilogueLandsOnceAtTheEnd() {
        let (loop, box) = makeLoop(
            apps: 3,
            step: .milliseconds(10)
        )
        #expect(loop.beginScan())
        defer { loop.stop() }

        var progress = loop.scanChunk(budget: .milliseconds(15))
        // Mid-pass: nothing summarised, nothing published — a
        // per-chunk epilogue would re-publish the displays several
        // times per boot and log a summary that is not one.
        #expect(box.summaries == 0)
        #expect(box.displayPublishes == 0)
        while !progress.finished {
            progress = loop.scanChunk(budget: .milliseconds(15))
        }

        #expect(box.summaries == 1)
        #expect(box.displayPublishes == 1)
        // The line still reports attaches of RUNNING apps, which
        // is what a field report is read against (#672).
        #expect(
            box.lines.contains {
                $0.hasPrefix("startup scan: 3 apps attached of 3 ")
            }
        )
    }

    @Test("a chunk after the queue emptied is inert")
    func aChunkAfterTheEndIsInert() {
        let (loop, box) = makeLoop(
            apps: 2,
            step: .milliseconds(10)
        )
        #expect(loop.beginScan())
        defer { loop.stop() }
        var progress = loop.scanChunk(budget: .milliseconds(15))
        while !progress.finished {
            progress = loop.scanChunk(budget: .milliseconds(15))
        }

        let extra = loop.scanChunk(budget: .milliseconds(15))

        // The driver stops on `finished`, but a stray call must
        // not double-end the signpost interval, log a second
        // summary or re-publish the displays.
        #expect(extra.finished)
        #expect(box.summaries == 1)
        #expect(box.displayPublishes == 1)
    }

    @Test("a nil budget drains the whole queue in one call")
    func nilBudgetDrainsInOneCall() {
        let (loop, box) = makeLoop(
            apps: 6,
            step: .milliseconds(600)
        )
        #expect(loop.beginScan())
        defer { loop.stop() }

        let progress = loop.scanChunk(budget: nil)

        // Even with a clock spending 600 ms per read: no budget
        // means no yield point, which is the contract every suite
        // that drives a whole scan in one turn rests on.
        #expect(progress.finished)
        #expect(box.attached.count == 6)
    }

    @Test("stop drops a pass in flight")
    func stopDropsThePassInFlight() {
        let (loop, _) = makeLoop(apps: 5, step: .milliseconds(10))
        #expect(loop.beginScan())
        _ = loop.scanChunk(budget: .milliseconds(15))
        #expect(!loop.bootScan.pending.isEmpty)

        loop.stop()

        // The queue names apps THIS run attached, so a later
        // start must re-derive it rather than resume a dead one.
        #expect(loop.bootScan.pending.isEmpty)
        #expect(loop.beginScan())
        #expect(loop.bootScan.total == 5)
        loop.stop()
    }
}
