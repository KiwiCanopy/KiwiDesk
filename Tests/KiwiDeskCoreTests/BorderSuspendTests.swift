import AppKit
import Testing

@testable import KiwiDeskCore

/// `BorderManager.setSuspended` freezes rings hidden for the duration
/// of Mission Control / Exposé (#4xx). The load-bearing invariant is
/// the *gate*: while suspended the show paths must no-op so a live
/// WindowServer event can't re-surface a ring over the overview. The
/// end-to-end hide/restore is inherently device-QA (real Mission
/// Control), so these pin the gate itself.
@Suite("Border suspend gate", .serialized)
@MainActor
struct BorderSuspendTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 200, height: 120),
            colorHex: "#0A84FF",
            width: 2,
            cornerStyle: .rounded
        )
    }

    @Test("A suspended manager ignores sync")
    func syncGatedWhileSuspended() {
        let manager = BorderManager()
        manager.setSuspended(true)
        manager.sync([spec(7)])
        #expect(manager.borderedWindows.isEmpty)
    }

    @Test("Resuming lets the next sync rebuild")
    func syncResumesAfterUnsuspend() {
        let manager = BorderManager()
        manager.sync([spec(7)])
        #expect(manager.borderedWindows == [WindowID(7)])
        manager.setSuspended(true)
        // A sync arriving mid-overview is dropped, not applied.
        manager.sync([spec(7), spec(8)])
        #expect(!manager.borderedWindows.contains(WindowID(8)))
        manager.setSuspended(false)
        manager.sync([spec(7), spec(8)])
        #expect(
            manager.borderedWindows == [WindowID(7), WindowID(8)]
        )
    }

    @Test("start() clears a stuck suspend flag")
    func startClearsSuspend() {
        let manager = BorderManager()
        // A stop() landing while Mission Control was up leaves the
        // flag set; a fresh start must un-stick it, or every later
        // sync would no-op forever.
        manager.setSuspended(true)
        #expect(manager.suspended)
        manager.start()
        #expect(!manager.suspended)
    }

    @Test("Toggling the same state is a no-op")
    func idempotentToggle() {
        let manager = BorderManager()
        manager.sync([spec(7)])
        // Already un-suspended: must not retire the live ring.
        manager.setSuspended(false)
        #expect(manager.borderedWindows == [WindowID(7)])
        manager.setSuspended(true)
        manager.setSuspended(true)
        #expect(manager.suspended)
    }
}
