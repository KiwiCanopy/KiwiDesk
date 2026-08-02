import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The boot path bounds AX messaging before it talks to any app
/// (#672). A hung process answers no AX call, and each call
/// against it blocks for the ~6 s system default — several
/// serial calls per app turned one stopped helper into a ~60 s
/// boot in the field. The stall itself is red-proved by the
/// deterministic device repro (`kill -STOP` a GUI app), never by
/// a real SIGSTOP here: tests.md forbids tight timing in CI, so
/// this suite pins the *wiring* through injected seams — the
/// timeout is applied, with the pinned value, before the scan
/// reads its first app.
@MainActor
@Suite("Startup AX messaging timeout (#672)")
struct StartupAXTimeoutTests {
    /// Builds a loop whose machine seams record instead of
    /// touching the host: no AX observer is created, no real
    /// app is scanned.
    private func makeLoop(
        recording order: @escaping @MainActor (String) -> Void
    ) -> EventLoop {
        let loop = EventLoop()
        loop.registersWorkspaceObservers = false
        loop.makeObserver = { _ in nil }
        loop.onLog = { _ in }
        loop.applyAXMessagingTimeout = { seconds in
            order("timeout \(seconds)")
        }
        loop.visiblePIDs = {
            order("prefilter")
            return []
        }
        loop.runningApplications = {
            order("scan")
            return []
        }
        return loop
    }

    @Test("start applies the ~1s timeout before the first scan")
    func timeoutPrecedesTheScan() {
        var order: [String] = []
        let loop = makeLoop { order.append($0) }
        loop.start()
        defer { loop.stop() }
        // Pin the value, not just the call: the whole point is
        // the bound, and 1.0 is an argued number (EventLoop.
        // axMessagingTimeoutSeconds' doc), so a drift should be
        // a conscious edit here too.
        #expect(order.first == "timeout 1.0")
        #expect(order.contains("prefilter"))
        #expect(order.contains("scan"))
    }

    @Test("a second start does not re-apply while running")
    func secondStartIsInert() {
        var applications = 0
        let loop = makeLoop { line in
            if line.hasPrefix("timeout") { applications += 1 }
        }
        loop.start()
        defer { loop.stop() }
        loop.start()
        #expect(applications == 1)
    }
}
