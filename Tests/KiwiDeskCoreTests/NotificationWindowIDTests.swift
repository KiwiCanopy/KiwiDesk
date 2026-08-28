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
