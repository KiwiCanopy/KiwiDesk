import AppKit
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A test core lists no real app, and its tripwires refuse, with
/// an issue, any attach to or frame for another running app
/// (#2289); a fixture's unused pid passes both.
@MainActor
@Suite("Live app list seam (#2289)")
struct LiveAppListSeamTests {
    private final class Writes: Sendable {
        let count = OSAllocatedUnfairLock(initialState: 0)
        func add() { count.withLock { $0 += 1 } }
        var total: Int { count.withLock { $0 } }
    }

    private static let frame = CGRect(x: 0, y: 0, width: 400, height: 300)

    /// A regular app the host runs, which no test may touch.
    nonisolated static var foreignApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            $0.processIdentifier > 0
                && $0.processIdentifier != getpid()
                && $0.activationPolicy == .regular
        }
    }

    /// A core whose frames for `pid` land in `writes`.
    private func core(
        framing pid: pid_t,
        into writes: Writes
    ) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.applier.writer = FrameWriter(
            setFrame: { _, _ in writes.add() },
            setPosition: { _, _ in writes.add() },
            writeEUI: { _, _ in }
        )
        let element = AXUIElementCreateApplication(pid)
        core.tiler.elementProvider = { _ in element }
        return core
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
        "an attach to another app is refused",
        .enabled(if: LiveAppListSeamTests.foreignApp != nil)
    )
    func foreignAttachRefused() throws {
        let app = try #require(Self.foreignApp)
        let core = makeTestCore()
        core.eventLoop.isRunning = true
        withKnownIssue {
            core.eventLoop.attach(
                pid: app.processIdentifier,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "app.test.foreign", name: "Foreign"),
                scanWindowsAtAttach: false
            )
        }
        #expect(core.eventLoop.observers.isEmpty)
    }

    @Test(
        "a frame for another app's window is refused",
        .enabled(if: LiveAppListSeamTests.foreignApp != nil)
    )
    func foreignFrameRefused() throws {
        let pid = try #require(Self.foreignApp).processIdentifier
        let writes = Writes()
        let core = core(framing: pid, into: writes)
        withKnownIssue {
            core.tiler.applier.apply(WindowID(1), Self.frame, setSize: true)
        }
        // The set would run on the app's own queue: drain it.
        core.tiler.applier.queue(for: pid).sync {}
        #expect(writes.total == 0)
    }

    /// The control: a fixture pid names no running process, so
    /// its frame is written as before.
    @Test("a fixture window's frame is still written")
    func fixtureFrameWritten() {
        let pid: pid_t = 902_289
        let writes = Writes()
        let core = core(framing: pid, into: writes)
        core.tiler.applier.apply(WindowID(1), Self.frame, setSize: true)
        core.tiler.applier.queue(for: pid).sync {}
        #expect(writes.total == 1)
    }
}
