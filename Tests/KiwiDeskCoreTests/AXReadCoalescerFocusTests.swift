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

    /// The lane suite's hang guard (tests.md): generous, since a
    /// passing run exits the instant the focus read lands, and
    /// only a merged lane — or a starved runner — reaches it.
    private static let laneHangGuard = Duration.seconds(30)

    @Test("A focus read is not parked behind a frame storm")
    func focusReadRidesItsOwnLane() async {
        // A frame read held open on the app's frame lane; the
        // focus read must still land. On one shared serial queue
        // it would wait behind the held read, and the guard
        // below would trip. Both requests are enqueued
        // synchronously, in this order, so the frame read is
        // dispatched first whatever the tasks below do.
        let coalescer = AXReadCoalescer()
        let gate = DispatchSemaphore(value: 0)
        nonisolated(unsafe) let held = elementA
        coalescer.reader = { element in
            if CFEqual(element, held) { gate.wait() }
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let (frameLanded, frameCont) = AsyncStream<Void>.makeStream()
        let (focusLanded, focusCont) = AsyncStream<Void>.makeStream()
        coalescer.request(
            .moved,
            window: WindowID(1),
            element: elementA,
            pid: pid
        ) { _ in frameCont.finish() }
        coalescer.requestFocus(element: elementB, pid: pid) { _ in
            focusCont.finish()
        }
        let landed = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in focusLanded {}
                return true
            }
            group.addTask {
                try? await Task.sleep(for: Self.laneHangGuard)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        #expect(landed, "the focus read waited behind the frame read")
        gate.signal()
        for await _ in frameLanded {}
    }
}
