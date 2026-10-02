import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A clock that advances one millisecond per read, so every
/// measured span is a known number of reads.
private final class StepClock: @unchecked Sendable {
    private let lock = NSLock()
    private var ticks: UInt64 = 0

    func read() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        ticks += 1_000_000
        return ticks
    }
}

/// The #1508 work counters: the meter's arithmetic, and the
/// engine sites that feed it — a pass's frames issued and
/// skipped, a park issued and skipped, events, switches and the
/// `get_work_counters` verb.
@Suite("Work meter (#1508)", .serialized)
@MainActor
struct WorkMeterTests {
    private func meter() -> WorkMeter {
        let clock = StepClock()
        return WorkMeter(now: { clock.read() })
    }

    @Test("An AX call counts against its thread with its span")
    func axSplitsByThread() {
        let m = meter()
        let answer = m.ax(isMain: true) { 7 }
        m.ax(isMain: false) {}
        m.ax(isMain: false) {}
        let c = m.snapshot(reset: false).counts
        #expect(answer == 7)
        #expect(c.axMainCalls == 1)
        #expect(c.axOffMainCalls == 2)
        // One clock read before the call and one after: 1 ms.
        #expect(c.axMainNanos == 1_000_000)
        #expect(c.axMainMaxNanos == 1_000_000)
        #expect(c.axOffMainNanos == 2_000_000)
    }

    @Test("A reset starts a new window")
    func resetZeroes() {
        let m = meter()
        m.add(\.retiles, 3)
        #expect(m.snapshot(reset: true).counts.retiles == 3)
        #expect(m.snapshot(reset: false).counts == .init())
    }

    @Test("The report derives the per-switch and per-retile rates")
    func reportDerives() {
        let m = meter()
        m.add(\.spaceSwitches, 2)
        m.add(\.retiles, 4)
        m.add(\.events, 6)
        for _ in 0..<5 { m.ax(isMain: true) {} }
        m.ax(isMain: false) {}
        guard case .object(let r) = m.report(reset: false) else {
            Issue.record("report is not an object")
            return
        }
        #expect(r["ax_calls_per_switch"] == .number(3))
        #expect(r["events_per_retile"] == .number(1.5))
        #expect(r["ax_main_ms_mean"] == .number(1))
        #expect(r["queue_wait_ms_mean"] == .null)
    }

    @Test("A park counts issued, already-parked and forced")
    func parksCount() {
        let engine = TilingEngine()
        let m = meter()
        engine.meter = m
        let bounds = CGRect(x: 0, y: 25, width: 1920, height: 1055)
        var window = ManagedWindow(
            id: WindowID(1),
            pid: 100,
            appName: "App",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600)
        )
        func park(force: Bool) {
            engine.stash(
                window,
                in: bounds,
                corner: .bottomRight,
                force: force,
                capturesOriginal: false
            )
        }
        park(force: false)
        window.frame = TilingEngine.stashFrame(
            window.frame,
            in: bounds,
            corner: .bottomRight
        )
        park(force: false)
        park(force: true)
        let c = m.snapshot(reset: false).counts
        #expect(c.parksIssued == 2)
        #expect(c.parksSkipped == 1)
    }

    @Test("A pass counts the frames it issues and the ones it skips")
    func framesCount() throws {
        guard NSScreen.main != nil else { return }
        let core = makeTestCore()
        let m = meter()
        core.tiler.meter = m
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, _, _ in }
        for raw in UInt32(1)...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(raw), pid: 1, appName: "A")
                )
            )
        }
        core.retile()
        // The echo: every window is where the pass put it.
        for (id, frame) in core.tiler.calculatedFrames(
            state: core.state
        ) {
            core.state.apply(.windowResized(id, frame))
        }
        _ = m.snapshot(reset: true)
        core.retile()
        var c = m.snapshot(reset: true).counts
        #expect(c.framesSkipped == 2)
        #expect(c.framesIssued == 0)
        #expect(c.retiles == 1)
        #expect(c.reissuePasses == 0)

        core.retile(animated: false, pass: .reissue)
        c = m.snapshot(reset: false).counts
        #expect(c.framesIssued == 2)
        #expect(c.framesSkipped == 0)
        #expect(c.reissuePasses == 1)
    }

    @Test("Events and explicit switches are counted where they enter")
    func eventsAndSwitches() {
        let core = makeTestCore()
        let m = meter()
        core.tiler.meter = m
        core.handle(.windowTitleChanged(WindowID(9), "x"))
        core.spaceSwitchRetile()
        let c = m.snapshot(reset: false).counts
        #expect(c.events == 1)
        #expect(c.spaceSwitches == 1)
        #expect(c.reissuePasses == 1)
    }

    @Test("A bar render and a ring sync are counted and timed")
    func barsAndBorders() {
        let core = makeTestCore()
        let m = meter()
        core.tiler.meter = m
        core.updateBars()
        core.updateBorders()
        core.updateBorders()
        let c = m.snapshot(reset: false).counts
        #expect(c.barRenders == 1)
        #expect(c.borderSyncs == 2)
        // The step clock reads once at each end of each pass.
        #expect(c.barNanos >= 1_000_000)
        #expect(c.borderMaxNanos >= 1_000_000)
    }

    @Test("get_work_counters reports and resets on request")
    func verbReportsAndResets() {
        let core = makeTestCore()
        let m = meter()
        core.tiler.meter = m
        m.add(\.retiles, 5)
        let first = core.execute(
            "get_work_counters",
            args: [.bool(true)]
        )
        guard case .object(let r) = first.data else {
            Issue.record("no report")
            return
        }
        #expect(r["retiles"] == .number(5))
        #expect(m.snapshot(reset: false).counts.retiles == 0)
    }
}
