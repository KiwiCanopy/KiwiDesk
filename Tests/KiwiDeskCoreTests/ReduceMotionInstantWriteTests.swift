import AppKit
import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// Under Reduce Motion an animated layout frame is written as an
/// instant set, `AXEnhancedUserInterface` held off around it
/// (#2187). The engine's own no-animation write holds nothing, so
/// an app with EUI on performed its own resize and its first echo
/// read as a refused size. The element is the test process's own,
/// so every block rides the main queue and `drain` waits them out.
@Suite("Reduce Motion writes through the instant set (#2187)")
@MainActor
struct ReduceMotionInstantWriteTests {
    private let id = WindowID(1)
    private let from = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let to = CGRect(x: 0, y: 0, width: 400, height: 300)

    private final class Log: Sendable {
        let calls = OSAllocatedUnfairLock<[String]>(initialState: [])
        func add(_ call: String) { calls.withLock { $0.append(call) } }
        var all: [String] { calls.withLock { $0 } }
    }

    private func makeEngine(_ log: Log) -> TilingEngine {
        let engine = TilingEngine()
        let element = AXUIElementCreateApplication(getpid())
        engine.applier.elementProvider = { _ in element }
        engine.applier.ownWindowMove = { _, _, _ in false }
        engine.applier.enhancedUIAtRest = { _ in true }
        engine.applier.writer = FrameWriter(
            setFrame: { _, _ in log.add("frame") },
            setPosition: { _, _ in log.add("position") },
            writeEUI: { _, on in log.add(on ? "on" : "off") }
        )
        engine.applier.clock = { 1_000 }
        engine.animation.reduceMotion = { true }
        return engine
    }

    private func drain() async {
        await withCheckedContinuation { done in
            DispatchQueue.main.async { done.resume() }
        }
    }

    @Test("An animated frame holds EUI off around one set")
    func animatedFrameHoldsEUI() async {
        let log = Log()
        let engine = makeEngine(log)
        engine.applyFrame(id, from: from, to: to, animated: true)
        await drain()
        #expect(log.all == ["off", "frame", "on"])
        #expect(engine.animation.isAnimating(window: id) == false)
    }

    /// The settle probe's stand-in (#2187): an app easing its
    /// own resize echoes a size it only passes through, and the
    /// probe's read past it is what tells that from a refusal.
    @Test("Only an animated frame under Reduce Motion owes a probe")
    func reducedFrameOwesTheProbe() {
        for (animated, reduced) in [
            (true, true), (false, true), (true, false),
        ] {
            let engine = makeEngine(Log())
            engine.animation.reduceMotion = { reduced }
            var owed: [WindowID] = []
            engine.onReducedMotionFrame = { owed.append($0) }
            engine.applyFrame(
                id,
                from: from,
                to: to,
                animated: animated
            )
            engine.animation.cancel(window: id)
            #expect(
                owed == (animated && reduced ? [id] : []),
                "animated \(animated), reduced \(reduced)"
            )
        }
    }

    @Test("The instant set stamps the commanded frame")
    func instantSetIsCommanded() {
        let engine = makeEngine(Log())
        engine.applyFrame(id, from: from, to: to, animated: true)
        #expect(engine.applier.instantTarget(id) == to)
    }
}
