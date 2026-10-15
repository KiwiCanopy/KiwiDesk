import AppKit
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A test run must never move the developer's real windows
/// (#2289). The app list every scan, reconcile and heal walks
/// defaulted LIVE in `makeTestCore`, so a suite that marked its
/// loop running and loaded a config attached every real app and
/// the retile resized their windows. Both twins pin the list
/// empty, and refuse — with an issue — any frame aimed at a
/// window of another running app, whatever route found it.
@MainActor
@Suite("Live app list seam (#2289)")
struct LiveAppListSeamTests {
    private final class Writes: Sendable {
        let count = OSAllocatedUnfairLock(initialState: 0)
        func add() { count.withLock { $0 += 1 } }
        var total: Int { count.withLock { $0 } }
    }

    private func counting(_ writes: Writes) -> FrameWriter {
        FrameWriter(
            setFrame: { _, _ in writes.add() },
            setPosition: { _, _ in writes.add() },
            writeEUI: { _, _ in }
        )
    }

    /// Another app the host runs, which a frame must never reach.
    nonisolated static var foreignPID: pid_t? {
        NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier > 0
                && $0.processIdentifier != getpid()
        }?.processIdentifier
    }

    @Test("the test core lists no running app")
    func listsNoApp() {
        // Non-vacuity: the live list this pin hides is not empty.
        #expect(!NSWorkspace.shared.runningApplications.isEmpty)
        #expect(makeTestCore().eventLoop.liveApps().isEmpty)
    }

    @Test("a running core's config load attaches no app")
    func configLoadAttachesNothing() {
        let core = makeTestCore()
        core.eventLoop.isRunning = true
        core.loadConfig()
        #expect(core.eventLoop.observers.isEmpty)
        #expect(core.eventLoop.elements.isEmpty)
    }

    @Test(
        "a frame for another app's window is refused",
        .enabled(if: LiveAppListSeamTests.foreignPID != nil)
    )
    func foreignFrameRefused() throws {
        let pid = try #require(Self.foreignPID)
        let core = makeTestCore()
        let writes = Writes()
        core.tiler.applier.writer = counting(writes)
        let element = AXUIElementCreateApplication(pid)
        core.tiler.elementProvider = { _ in element }
        withKnownIssue {
            core.tiler.applier.apply(
                WindowID(1),
                CGRect(x: 0, y: 0, width: 400, height: 300),
                setSize: true
            )
        }
        #expect(writes.total == 0)
    }

    /// The control: a fixture element names no running process,
    /// so its frame is written as before.
    @Test("a fixture window's frame is still written")
    func fixtureFrameWritten() async {
        let core = makeTestCore()
        let writes = Writes()
        core.tiler.applier.writer = counting(writes)
        let element = AXUIElementCreateApplication(902_289)
        core.tiler.elementProvider = { _ in element }
        core.tiler.applier.apply(
            WindowID(1),
            CGRect(x: 0, y: 0, width: 400, height: 300),
            setSize: true
        )
        // Generous hang-guard (#344): the set runs on the app's
        // own queue.
        for _ in 0..<500 where writes.total == 0 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(writes.total == 1)
    }
}
