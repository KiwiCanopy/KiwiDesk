import AppKit
import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// The AX calls an instant set costs (#1508): a run of sets
/// queued back to back holds `AXEnhancedUserInterface` off ONCE,
/// the hold agrees with the animation ref-count (#881), the
/// at-rest value is the event loop's and a hold restores what the
/// loop left, and a right-corner park moves the window without
/// sizing it. The element is the test process's own, so every
/// block rides the main queue and `drain` waits them out; the
/// writer records instead of messaging.
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
        func count(_ call: String) -> Int { all.filter { $0 == call }.count }
    }

    private func writer(_ log: Log) -> FrameWriter {
        FrameWriter(
            setFrame: { _, _ in log.add("frame") },
            setPosition: { _, _ in log.add("position") },
            writeEUI: { _, on in log.add(on ? "on" : "off") }
        )
    }

    private func makeApplier(_ log: Log, warmed: Bool) -> FrameApplier {
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(getpid())
        applier.elementProvider = { _ in element }
        applier.writer = writer(log)
        applier.enhancedUIAtRest = { _ in warmed }
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
        let applier = makeApplier(log, warmed: true)
        applier.applyInstant(w1, rect, setSize: true)
        applier.applyInstant(w2, rect, setSize: true)
        applier.applyInstant(w1, rect, setSize: false)
        await drain()
        #expect(log.all == ["off", "frame", "frame", "position", "on"])
        applier.applyInstant(w1, rect, setSize: true)
        await drain()
        #expect(log.all.suffix(3) == ["off", "frame", "on"])
    }

    @Test("An app the loop has not warmed is never toggled")
    func unwarmedAppIsNotToggled() async {
        let log = Log()
        let applier = makeApplier(log, warmed: false)
        applier.beginAnimating(w2)
        applier.applyInstant(w1, rect, setSize: true)
        applier.endAnimating(w2)
        await drain()
        #expect(log.all == ["frame"])
    }

    @Test("An animation's hold outlasts the instant batch inside it")
    func animationHoldAgrees() async {
        let log = Log()
        let applier = makeApplier(log, warmed: true)
        applier.beginAnimating(w2)
        applier.applyInstant(w1, rect, setSize: true)
        await drain()
        #expect(log.all == ["off", "frame"])
        applier.endAnimating(w2)
        await drain()
        #expect(log.all == ["off", "frame", "on"])
    }

    @Test("A hold open across a retirement restores what the loop left")
    func retiredHoldRestoresTheLoopsValue() async {
        for leftOn in [false, true] {
            let log = Log()
            let applier = makeApplier(log, warmed: true)
            applier.beginAnimating(w2)
            await drain()
            applier.retireApp(getpid(), leftOn: leftOn)
            applier.endAnimating(w2)
            await drain()
            #expect(log.all == (leftOn ? ["off", "on"] : ["off"]))
        }
    }

    /// The wiring: bootstrap hands the applier the loop's warmed
    /// baseline, and the loop's detach retires the hold.
    @Test("The loop's baseline and its detach reach the holds")
    func loopWiring() async {
        let core = makeTestCore()
        let log = Log()
        let pid = getpid()
        let element = AXUIElementCreateApplication(pid)
        let applier = core.tiler.applier
        applier.elementProvider = { _ in element }
        applier.writer = writer(log)
        core.eventLoop.writeEnhancedUI = { _, _ in }
        applier.applyInstant(w1, rect, setSize: true)
        await drain()
        #expect(log.all == ["frame"])
        core.eventLoop.enhancedUIBaselines[pid] = false
        applier.beginAnimating(w2)
        await drain()
        core.eventLoop.detach(pid: pid, restoreEnhancedUI: true)
        applier.endAnimating(w2)
        await drain()
        #expect(log.all == ["frame", "off"])
    }

    /// The consumer: a Space switch's park through the real
    /// `focus_space`. Display pinned (#531); the applier's clock
    /// is frozen by `makeTestCore`. `neighbor` puts a screen on
    /// the right of the host's, which flips the park to the left
    /// corner: the stash measures the real screen (tests.md).
    private func switchCounts(neighbor: Bool) async -> Log {
        let core = makeTestCore()
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        core.tiler.visibleBounds = { _ in bounds }
        let host = NSScreen.screens.map(GeometryUtils.axVisibleFrame)
        core.tiler.allScreenBounds = {
            neighbor
                ? host + host.map { $0.offsetBy(dx: $0.width, dy: 0) }
                : host
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
        core.tiler.applier.writer = writer(log)
        await drain()
        core.execute("focus_space", args: [.string("2")])
        await drain()
        return log
    }

    @Test(
        "A right-corner park moves the window without sizing it",
        .enabled(if: NSScreen.screens.count == 1)
    )
    func rightParkIsPositionOnly() async {
        let log = await switchCounts(neighbor: false)
        // w2 is placed (sized); w1 leaves view and parks.
        #expect(log.count("frame") == 1)
        #expect(log.count("position") == 1)
    }

    @Test(
        "A left-corner park is sized: its x reads the state width",
        .enabled(if: NSScreen.screens.count == 1)
    )
    func leftParkIsSized() async {
        let log = await switchCounts(neighbor: true)
        #expect(log.count("frame") == 2)
        #expect(log.count("position") == 0)
    }
}
