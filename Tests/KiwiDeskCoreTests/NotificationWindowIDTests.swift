import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// How a move/resize notification learns which window it is
/// about (#1084).
///
/// `AXHelper.windowID(of:)` is `_AXUIElementGetWindow`, a
/// synchronous MIG round-trip into the observed app, made on
/// the main thread — the thread that delivers the
/// `CADisplayLink` callback. Every frame KiwiDesk applies emits
/// a notification, so paying that call per notification made a
/// resize fund its own frame-clock starvation: device capture
/// 2026-08-28 measured 42 stalls in ten seconds of held resize,
/// up to 607 ms, against 1 stall at 134 ms after this change —
/// at a HIGHER load average (24.5 against 16–21).
///
/// The tracked element map answers the same question for a
/// window already adopted, in process and with no IPC. This
/// suite holds the ORDER, which is the whole fix and a
/// one-line thing to invert back.
@Suite("Notification window-id resolution (#1084)")
@MainActor
struct NotificationWindowIDTests {
    private let element = AXUIElementCreateSystemWide()

    /// Per-file, as the convention wants — the loop refuses to
    /// handle a notification for an app it is not observing.
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

    private func makeLoop(
        id: WindowID,
        pid: pid_t,
        asks: @escaping @MainActor () -> Void
    ) -> EventLoop {
        let loop = EventLoop()
        // The seam stands in for the round-trip: production
        // resolves through `AXHelper.windowID(of:)`, and a call
        // here means a call into the app there.
        loop.resolveWindowID = { _ in
            asks()
            return id
        }
        loop.frameReads.reader = { _ in .zero }
        loop.frameReads.deliver = { work in
            MainActor.assumeIsolated { work() }
        }
        loop.frameReads.dispatchOverride = { _, _ in }
        loop.observers[pid] = FakeObserver()
        return loop
    }

    @Test("A tracked window is resolved without asking the app")
    func trackedWindowNeverAsksTheApp() {
        let id = WindowID(42)
        let pid = pid_t(getpid())
        var asked = 0
        let loop = makeLoop(id: id, pid: pid) { asked += 1 }
        // Adopted: the map already knows this element.
        loop.elements[pid] = [id: element]
        for note in [
            kAXWindowResizedNotification,
            kAXWindowMovedNotification,
        ] {
            loop.handle(
                note,
                element,
                pid: pid,
                app: AppRef(bundleID: nil, name: "Test")
            )
        }
        // The whole fix: no round-trip for a window we track.
        // Inverting the resolver's order reds here, and the
        // frame clock starves again on device.
        #expect(asked == 0)
    }

    @Test("A dead element's zero frame never reaches state")
    func deadElementFrameIsDropped() {
        // The liveness property map-first LOST (#1084 review).
        // Asking the app filtered destroyed elements for free —
        // they answer no id, so the arm returned before reading.
        // The map still names a window whose entry the destroy
        // sweep has not reached, so the read happens, and
        // `AXHelper.frame` answers `.zero` for a dead element.
        // A real on-screen window never has that frame, so it is
        // dropped at delivery rather than folded into state
        // where the overlays would follow it — device-observed
        // as a window snapping to the corner (2026-08-29).
        let id = WindowID(9)
        let pid = pid_t(getpid())
        let loop = makeLoop(id: id, pid: pid) {}
        loop.elements[pid] = [id: element]
        loop.frameReads.reader = { _ in .zero }
        // The read must actually RUN, or this test passes for
        // the wrong reason — the shared fixture discards the
        // work, which made a first draft of this vacuous.
        loop.frameReads.dispatchOverride = { _, work in work() }
        var events: [KiwiEvent] = []
        loop.onEvent = { events.append($0) }
        loop.handle(
            kAXWindowResizedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
        #expect(events.isEmpty)
        #expect(loop.trackedFrames[id] == nil)
    }

    @Test("An ambiguous element asks rather than guessing")
    func duplicateMappingAsksTheApp() {
        // Architect review + device, 2026-08-29: the map is
        // keyed by id, so two ids CAN point at one element, and
        // a Dictionary's iteration order is undefined — picking
        // "the first" match is a coin flip per notification, and
        // the wrong side of it moves the wrong window. Observed
        // while merging Finder tabs: windows slid sideways and
        // an unrelated app minimized, intermittently, which is
        // what a per-notification coin flip looks like from
        // outside.
        //
        // The app is the one party that can settle it, so an
        // ambiguous element goes back to the ask. Reverting to
        // `first(where:)` makes this test's outcome depend on
        // hash order — it does not merely fail, it becomes
        // unreliable, which is the property being removed.
        let pid = pid_t(getpid())
        var asked = 0
        let loop = makeLoop(id: WindowID(1), pid: pid) {
            asked += 1
        }
        // Two ids, one element — the shape a re-key that failed
        // to remove its old key would leave behind.
        loop.elements[pid] = [
            WindowID(1): element,
            WindowID(2): element,
        ]
        loop.handle(
            kAXWindowResizedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
        #expect(asked == 1)
    }

    @Test("An unknown window still asks — the map is not a wall")
    func untrackedWindowStillAsks() {
        // The fallback must stay, and stay SECOND: a window not
        // yet adopted has no map entry, and the ask is the only
        // thing that can name it. A "fix" that simply dropped
        // the call would pass the test above and lose every
        // notification for a new window.
        let id = WindowID(7)
        let pid = pid_t(getpid())
        var asked = 0
        let loop = makeLoop(id: id, pid: pid) { asked += 1 }
        loop.elements[pid] = [:]
        loop.handle(
            kAXWindowResizedNotification,
            element,
            pid: pid,
            app: AppRef(bundleID: nil, name: "Test")
        )
        #expect(asked == 1)
    }
}
