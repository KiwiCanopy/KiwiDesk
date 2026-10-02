import AppKit
import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// The AX calls an instant set costs (#1508): a run of sets
/// queued back to back holds `AXEnhancedUserInterface` off ONCE,
/// the at-rest value is read once per app, the hold agrees with
/// the animation ref-count (#881), and a park moves the window
/// without sizing it. The element is the test process's own, so
/// every block rides the main queue and `drain` waits them out;
/// the writer records instead of messaging.
@Suite("Instant sets batch their EUI hold (#1508)", .serialized)
@MainActor
struct FrameApplierBatchTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 100)

    private final class Log: Sendable {
        let calls = OSAllocatedUnfairLock<[String]>(initialState: [])
        func add(_ call: String) { calls.withLock { $0.append(call) } }
        var all: [String] { calls.withLock { $0 } }
    }

    private func writer(_ log: Log, answers: Bool?) -> FrameWriter {
        FrameWriter(
            setFrame: { _, _ in log.add("frame") },
            setPosition: { _, _ in log.add("position") },
            readEUI: { _ in
                log.add("read")
                return answers
            },
            writeEUI: { _, on in log.add(on ? "on" : "off") }
        )
    }

    private func makeApplier(_ log: Log, answers: Bool?) -> FrameApplier {
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(getpid())
        applier.elementProvider = { _ in element }
        applier.writer = writer(log, answers: answers)
        return applier
    }

    /// Every block queued so far has run: the main queue is
    /// serial and FIFO.
    private func drain() async {
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
    }

    @Test("Sets queued back to back share one hold")
    func batchTogglesOnce() async {
        let log = Log()
        let applier = makeApplier(log, answers: true)
        applier.applyInstant(w1, rect)
        applier.applyInstant(w2, rect)
        applier.applyInstant(w1, rect, setSize: false)
        await drain()
        #expect(
            log.all
                == ["read", "off", "frame", "frame", "position", "on"]
        )
    }

    @Test("The at-rest value is read once per app")
    func atRestIsCached() async {
        let log = Log()
        let applier = makeApplier(log, answers: true)
        applier.applyInstant(w1, rect)
        await drain()
        applier.applyInstant(w1, rect)
        await drain()
        #expect(
            log.all == ["read", "off", "frame", "on", "off", "frame", "on"]
        )
        applier.forgetApp(getpid())
        applier.applyInstant(w1, rect)
        await drain()
        #expect(log.all.filter { $0 == "read" }.count == 2)
    }

    @Test("An app that does not answer is never toggled, and re-asked")
    func unansweredReadIsNotCached() async {
        let log = Log()
        let applier = makeApplier(log, answers: nil)
        applier.applyInstant(w1, rect)
        await drain()
        applier.applyInstant(w1, rect)
        await drain()
        #expect(log.all == ["read", "frame", "read", "frame"])
    }

    @Test("An animation's hold outlasts the instant batch inside it")
    func animationHoldAgrees() async {
        let log = Log()
        let applier = makeApplier(log, answers: true)
        applier.beginAnimating(w2)
        applier.applyInstant(w1, rect)
        await drain()
        #expect(log.all == ["read", "off", "frame"])
        applier.endAnimating(w2)
        await drain()
        #expect(log.all == ["read", "off", "frame", "on"])
    }

    /// The consumer: a Space switch's park goes out position
    /// only, through the real `focus_space`. Display pinned
    /// (#531); the applier's clock is frozen by `makeTestCore`.
    @Test("A park moves the window without sizing it")
    func parkIsPositionOnly() async {
        guard NSScreen.main != nil else { return }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.animation.isEnabled = false
        for (id, space) in [(w1, 1), (w2, 2)] {
            core.state.apply(
                .windowCreated(ManagedWindow(id: id, pid: 1, appName: "A"))
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        core.retile()
        let log = Log()
        let element = AXUIElementCreateApplication(getpid())
        core.tiler.applier.elementProvider = { _ in element }
        core.tiler.applier.writer = writer(log, answers: nil)
        await drain()
        core.execute("focus_space", args: [.string("2")])
        await drain()
        // w2 is placed (sized); w1 leaves view and parks.
        #expect(log.all.filter { $0 == "frame" }.count == 1)
        #expect(log.all.filter { $0 == "position" }.count == 1)
    }
}
