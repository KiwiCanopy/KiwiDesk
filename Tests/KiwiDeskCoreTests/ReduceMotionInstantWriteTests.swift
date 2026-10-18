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
/// so every block rides the main queue and `drain` waits them out;
/// a cross-screen resend is captured and fired by hand.
@Suite("Reduce Motion writes through the instant set (#2187)")
@MainActor
struct ReduceMotionInstantWriteTests {
    private let id = WindowID(1)
    private let from = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let to = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let left = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let right = CGRect(
        x: 1728,
        y: -151,
        width: 2560,
        height: 1440
    )
    private let onRight = CGRect(x: 3773, y: 588, width: 508, height: 687)

    @MainActor private final class Resends {
        var owed: [@MainActor () -> Void] = []
        func fire() {
            let due = owed
            owed = []
            due.forEach { $0() }
        }
    }

    private final class Log: Sendable {
        let calls = OSAllocatedUnfairLock<[String]>(initialState: [])
        func add(_ call: String) { calls.withLock { $0.append(call) } }
        var all: [String] { calls.withLock { $0 } }
    }

    private func makeEngine(
        _ log: Log,
        resends: Resends = Resends()
    ) -> TilingEngine {
        let engine = TilingEngine()
        let element = AXUIElementCreateApplication(getpid())
        engine.applier.elementProvider = { _ in element }
        engine.applier.ownWindowMove = { _, _, _ in false }
        engine.applier.enhancedUIAtRest = { _ in true }
        engine.applier.writer = FrameWriter(
            setFrame: { rect, _ in
                log.add("frame \(Int(rect.width))x\(Int(rect.height))")
            },
            setPosition: { _, _ in log.add("position") },
            writeEUI: { _, on in log.add(on ? "on" : "off") }
        )
        engine.applier.clock = { 1_000 }
        engine.applier.scheduleResend = { _, work in
            resends.owed.append(work)
        }
        engine.allScreenBounds = { [left, right] }
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
        #expect(log.all == ["off", "frame 400x300", "on"])
        #expect(engine.animation.isAnimating(window: id) == false)
    }

    /// The settle probe's stand-in (#2187): an app easing its
    /// own resize echoes a size it only passes through, and the
    /// probe's read past it is what tells that from a refusal.
    /// A re-issuing pass owes none, or a switch reads every window.
    @Test("Only an instant event-pass ask owes the probe")
    func instantAskOwesTheProbe() {
        for pass in [RetilePass.event, .reissue, .apply] {
            for animated in [true, false] {
                for reduced in [true, false] {
                    let owes = TilingEngine.instantAskOwesProbe(
                        pass: pass,
                        animated: animated,
                        reduceMotion: reduced
                    )
                    let instant = !animated || reduced
                    #expect(
                        owes == (pass == .event && instant),
                        "\(pass) animated \(animated) reduced \(reduced)"
                    )
                }
            }
        }
    }

    /// An app easing its frame clamps the first set's size to
    /// the screen it left (#2187, Zen at 588 + 529 = the laptop's
    /// 1117), so a set onto another screen writes again later.
    @Test("A set onto another screen writes its frame again")
    func crossScreenSetWritesAgain() async {
        let log = Log()
        let resends = Resends()
        let engine = makeEngine(log, resends: resends)
        engine.applyFrame(id, from: from, to: onRight, animated: true)
        await drain()
        #expect(resends.owed.count == 1)
        resends.fire()
        await drain()
        let set = ["off", "frame 508x687", "on"]
        #expect(log.all == set + set)
    }

    @Test("A set on its own screen writes once")
    func sameScreenSetWritesOnce() async {
        let resends = Resends()
        let engine = makeEngine(Log(), resends: resends)
        engine.applyFrame(id, from: from, to: to, animated: true)
        #expect(resends.owed.isEmpty)
    }

    /// A park or a later pass inside the delay is the newer ask;
    /// the resend must not put the old frame back over it.
    @Test("A newer write cancels the resend")
    func newerWriteCancelsTheResend() async {
        let log = Log()
        let resends = Resends()
        let engine = makeEngine(log, resends: resends)
        engine.applyFrame(id, from: from, to: onRight, animated: true)
        engine.setFrame(id, to, setSize: false)
        await drain()
        let written = log.all
        resends.fire()
        await drain()
        #expect(log.all == written)
    }

    /// A parked corner may lie mostly on a neighbour, so an
    /// unpark would read as a crossing on every Space switch.
    @Test("An unpark from a corner owes no resend")
    func unparkOwesNoResend() {
        let resends = Resends()
        let engine = makeEngine(Log(), resends: resends)
        let parked = TilingEngine.stashFrame(
            to,
            in: left,
            corner: .bottomRight
        )
        #expect(engine.looksStashed(parked))
        #expect(
            GeometryUtils.crosses(
                from: parked,
                to: to,
                among: [left, right]
            )
        )
        engine.applyFrame(id, from: parked, to: to, animated: false)
        #expect(resends.owed.isEmpty)
    }

    @Test("The instant set stamps the commanded frame")
    func instantSetIsCommanded() {
        let engine = makeEngine(Log())
        engine.applyFrame(id, from: from, to: to, animated: true)
        #expect(engine.applier.instantTarget(id) == to)
    }
}
