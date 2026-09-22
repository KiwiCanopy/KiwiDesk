import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The focus read's two shapes in the coalescer (#1088): keyed
/// per APP, because `kAXFocusedWindowChanged` is a single-valued
/// stream, and on its own per-app lane, because its consumers
/// read wall-clock ledgers a frame storm's queue depth would age
/// it past.
///
/// The first clause pumps by hand; the second runs the REAL
/// queues — the lane is the property, and no override can see
/// it — under a generous hang guard (tests.md).
@Suite("AX read coalescer — focus (#1088)")
@MainActor
struct AXReadCoalescerFocusTests {
    @MainActor
    private final class Pump {
        var work: [@Sendable () -> Void] = []
        func drainOne() {
            guard !work.isEmpty else { return }
            work.removeFirst()()
        }
    }

    private let pid: pid_t = 424_242
    private let elementA = AXUIElementCreateSystemWide()
    private let elementB = AXUIElementCreateApplication(424_242)

    @Test("Focus reads coalesce per app — the newest window wins")
    func focusReadsCoalescePerApp() {
        // A, A (#887's duplicate), B while A's read is in flight.
        // Keyed per window, A's duplicate would dispatch behind
        // B's read on the serial queue and deliver LAST — state
        // on A while the app ended on B. Per app, the queued
        // slot holds the newest window and B is what lands.
        let pump = Pump()
        let coalescer = AXReadCoalescer()
        coalescer.reader = { _ in
            CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        coalescer.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        coalescer.dispatchOverride = { _, work in
            pump.work.append(work)
        }
        var delivered: [String] = []
        coalescer.requestFocus(element: elementA, pid: pid) { _ in
            delivered.append("A")
        }
        coalescer.requestFocus(element: elementA, pid: pid) { _ in
            delivered.append("A")
        }
        coalescer.requestFocus(element: elementB, pid: pid) { _ in
            delivered.append("B")
        }
        #expect(pump.work.count == 1, "one focus read per app")
        pump.drainOne()
        #expect(delivered == ["A"])
        #expect(pump.work.count == 1, "the newest window re-reads")
        pump.drainOne()
        #expect(delivered == ["A", "B"])
        #expect(pump.work.isEmpty)
    }

    /// The lane clause's hang guard (tests.md): a `Date()`
    /// deadline poll rather than an awaited handle, because a
    /// task-group watchdog racing a never-completing main-actor
    /// await never resumed under swift-testing — the guard's
    /// first shape hung a mutated run for 16 minutes instead of
    /// redding it (guard-prover, 2026-09-22). Generous: a passing
    /// run exits the instant the focus read lands.
    private static let laneHangGuard: TimeInterval = 30

    @MainActor
    private final class Landing {
        var focus = false
        var frame = false
    }

    private func wait(
        until landed: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(Self.laneHangGuard)
        while !landed(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("A focus read is not parked behind a frame storm")
    func focusReadRidesItsOwnLane() async {
        // A frame read held open on the app's frame lane; the
        // focus read must still land. On one shared serial queue
        // it would wait behind the held read, and the guard
        // below would trip. Both requests are enqueued
        // synchronously, in this order, so the frame read is
        // dispatched first.
        let coalescer = AXReadCoalescer()
        let gate = DispatchSemaphore(value: 0)
        nonisolated(unsafe) let held = elementA
        coalescer.reader = { element in
            if CFEqual(element, held) { gate.wait() }
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let landing = Landing()
        coalescer.request(
            .moved,
            window: WindowID(1),
            element: elementA,
            pid: pid
        ) { _ in landing.frame = true }
        coalescer.requestFocus(element: elementB, pid: pid) { _ in
            landing.focus = true
        }
        await wait { landing.focus }
        #expect(landing.focus, "the focus read waited behind the frame read")
        #expect(!landing.frame, "the held frame read delivered")
        gate.signal()
        await wait { landing.frame }
        #expect(landing.frame, "the released frame read never landed")
    }
}
