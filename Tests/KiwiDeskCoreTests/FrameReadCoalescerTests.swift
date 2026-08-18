import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The off-main frame read behind move/resize notifications
/// (#618): one read in flight per (window, kind), storms
/// coalesce to a dirty re-read, and the FINAL frame always
/// lands. Driven synchronously through the injected seams —
/// the reads are captured and pumped by hand, so nothing here
/// waits on a real queue (tests.md: no tight deadlines).
@Suite("Frame read coalescer (#618)")
@MainActor
struct FrameReadCoalescerTests {
    /// Captured read work, pumped manually to model an app
    /// answering late.
    @MainActor
    private final class Pump {
        var work: [(pid: pid_t, run: @Sendable () -> Void)] = []

        func drainOne() {
            guard !work.isEmpty else { return }
            work.removeFirst().run()
        }
    }

    private func makeCoalescer(
        pump: Pump,
        frames: @escaping @Sendable () -> CGRect
    ) -> FrameReadCoalescer {
        let coalescer = FrameReadCoalescer()
        coalescer.reader = { _ in frames() }
        // Immediate main hop: the pump already runs on the
        // main actor, so delivery is synchronous and ordered.
        coalescer.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        coalescer.dispatchOverride = { pid, work in
            pump.work.append((pid: pid, run: work))
        }
        return coalescer
    }

    private let element = AXUIElementCreateSystemWide()

    @Test("A storm coalesces to one read plus one re-read")
    func stormCoalesces() {
        let pump = Pump()
        nonisolated(unsafe) var frame = CGRect(
            x: 0,
            y: 0,
            width: 800,
            height: 600
        )
        let coalescer = makeCoalescer(pump: pump) { frame }
        var delivered: [CGRect] = []
        for _ in 0..<10 {
            coalescer.request(
                .resized,
                window: WindowID(1),
                element: element,
                pid: 7
            ) { delivered.append($0) }
        }
        // Ten notifications while the app is busy: exactly one
        // read was scheduled.
        #expect(pump.work.count == 1)
        // The app answers; the window has moved on meanwhile.
        pump.drainOne()
        #expect(delivered.count == 1)
        // Dirty: one re-read was scheduled so the final frame
        // lands too.
        #expect(pump.work.count == 1)
        frame = CGRect(x: 0, y: 0, width: 563, height: 600)
        pump.drainOne()
        #expect(delivered.count == 2)
        #expect(delivered.last?.width == 563)
        // Drained: nothing further is in flight.
        #expect(pump.work.isEmpty)
    }

    @Test("A quiet request reads once and stops")
    func quietRequestReadsOnce() {
        let pump = Pump()
        let answer = CGRect(x: 1, y: 2, width: 3, height: 4)
        let coalescer = makeCoalescer(pump: pump) { answer }
        var delivered: [CGRect] = []
        coalescer.request(
            .moved,
            window: WindowID(1),
            element: element,
            pid: 7
        ) { delivered.append($0) }
        pump.drainOne()
        #expect(delivered == [answer])
        #expect(pump.work.isEmpty)
    }

    @Test("Keys are independent per window and per kind")
    func keysAreIndependent() {
        let pump = Pump()
        let coalescer = makeCoalescer(pump: pump) { .zero }
        var count = 0
        // Same window, both kinds; plus a second window: three
        // distinct keys, three reads in flight at once.
        coalescer.request(
            .moved,
            window: WindowID(1),
            element: element,
            pid: 7
        ) { _ in count += 1 }
        coalescer.request(
            .resized,
            window: WindowID(1),
            element: element,
            pid: 7
        ) { _ in count += 1 }
        coalescer.request(
            .resized,
            window: WindowID(2),
            element: element,
            pid: 7
        ) { _ in count += 1 }
        #expect(pump.work.count == 3)
        pump.drainOne()
        pump.drainOne()
        pump.drainOne()
        #expect(count == 3)
        #expect(pump.work.isEmpty)
    }

    @Test("The notification arm routes through the coalescer")
    func notificationArmRoutesThroughCoalescer() {
        // The wire (#618): a resized notification must NOT read
        // the frame inline on the main actor — it schedules the
        // read and delivers the event afterwards, with the
        // tracked frame refreshed. Reverting the arm to the
        // inline read leaves this red (the event would land
        // before the pump ran).
        let loop = EventLoop()
        let pump = Pump()
        let id = WindowID(42)
        let answer = CGRect(x: 5, y: 6, width: 700, height: 500)
        loop.resolveWindowID = { _ in id }
        loop.frameReads.reader = { _ in answer }
        loop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.frameReads.dispatchOverride = { pid, work in
            pump.work.append((pid: pid, run: work))
        }
        let pid = pid_t(getpid())
        loop.observers[pid] = FakeObserver()
        loop.elements[pid] = [id: element]
        var events: [KiwiEvent] = []
        loop.onEvent = { events.append($0) }
        loop.handle(
            kAXWindowResizedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
        // Nothing inline: the read is scheduled, not performed.
        #expect(events.isEmpty)
        #expect(pump.work.count == 1)
        pump.drainOne()
        #expect(events.count == 1)
        if case .windowResized(let got, let frame) = events
            .first
        {
            #expect(got == id)
            #expect(frame == answer)
        } else {
            Issue.record("expected a windowResized event")
        }
        #expect(loop.trackedFrames[id] == answer)
    }

    @Test("A read completing after detach delivers nothing")
    func detachDropsPendingDelivery() {
        // The ownership re-check (review, 2026-08-18): `stop()`
        // and a detach clear the observer, and a read still in
        // flight then must not fold a stale event into a
        // torn-down core.
        let loop = EventLoop()
        let pump = Pump()
        let id = WindowID(42)
        loop.resolveWindowID = { _ in id }
        loop.frameReads.reader = { _ in .zero }
        loop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.frameReads.dispatchOverride = { pid, work in
            pump.work.append((pid: pid, run: work))
        }
        let pid = pid_t(getpid())
        loop.observers[pid] = FakeObserver()
        var events: [KiwiEvent] = []
        loop.onEvent = { events.append($0) }
        loop.handle(
            kAXWindowMovedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
        #expect(pump.work.count == 1)
        // The app detaches while the read is in flight.
        loop.observers[pid] = nil
        pump.drainOne()
        #expect(events.isEmpty)
    }

    /// Inert healthy observer (the `StartupWarmupSkipTests`
    /// shape): attach state only, nothing fires.
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

    @Test("The newest request's completion wins a coalesce")
    func newestCompletionWins() {
        let pump = Pump()
        let coalescer = makeCoalescer(pump: pump) { .zero }
        var winner = ""
        coalescer.request(
            .resized,
            window: WindowID(1),
            element: element,
            pid: 7
        ) { _ in winner = "first" }
        coalescer.request(
            .resized,
            window: WindowID(1),
            element: element,
            pid: 7
        ) { _ in winner = "second" }
        // First read answers the first completion; the re-read
        // must answer the NEWEST request, never replay the
        // superseded middle ones.
        pump.drainOne()
        #expect(winner == "first")
        pump.drainOne()
        #expect(winner == "second")
    }
}
