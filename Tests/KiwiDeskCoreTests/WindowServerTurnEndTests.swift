import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An event's restack is paid once per window at the run loop
/// turn's end (#2659): one raise sends a reorder and an unhide,
/// and each ordered the ring again, a WindowServer round trip
/// that was a no-op in 228 of 343 same-turn orders on device.
@Suite("WindowServer watch turn-end restack")
@MainActor
struct WindowServerTurnEndTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    /// A watch whose turn end the test runs by hand, recording
    /// every hook call in order.
    private func turnWatch(markHides: Bool = true) -> (
        WindowServerWatch, endTurn: () -> Void, calls: () -> [String]
    ) {
        final class Box {
            var calls: [String] = []
            var turn: [@MainActor () -> Void] = []
        }
        let box = Box()
        let watch = WindowServerWatch()
        watch.readWindowBounds = { _ in .zero }
        watch.atTurnEnd = { box.turn.append($0) }
        for consumer in WindowServerWatch.Consumer.allCases {
            let name = "\(consumer)"
            var hooks = WindowServerWatch.Hooks()
            hooks.restack = { id in
                box.calls.append("\(name).restack w\(id.raw)")
            }
            if consumer != .mark || markHides {
                hooks.hide = { id in
                    box.calls.append("\(name).hide w\(id.raw)")
                }
            }
            watch.connect(consumer, hooks)
        }
        let endTurn = {
            while !box.turn.isEmpty {
                let work = box.turn
                box.turn = []
                for run in work { run() }
            }
        }
        return (watch, endTurn, { box.calls })
    }

    @Test("a turn's reorders and unhide restack once, at its end")
    func oncePerTurn() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1], for: .ring)
        watch.request([w1], for: .vision)
        watch.handle(.reorder, window: w1)
        watch.handle(.unhide, window: w1)
        watch.handle(.reorder, window: w1)
        #expect(calls().isEmpty)
        endTurn()
        #expect(calls() == ["ring.restack w1", "vision.restack w1"])
        endTurn()
        #expect(calls().count == 2)
        // A later turn owes and pays again.
        watch.handle(.reorder, window: w1)
        endTurn()
        #expect(calls().count == 4)
    }

    @Test("windows restack in the order their events arrived")
    func arrivalOrder() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1, w2], for: .ring)
        watch.handle(.reorder, window: w2)
        watch.handle(.reorder, window: w1)
        watch.handle(.reorder, window: w2)
        endTurn()
        #expect(calls() == ["ring.restack w2", "ring.restack w1"])
    }

    @Test("a hide after a reorder ends the turn hidden")
    func hideDropsTheOwedRestack() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1, w2], for: .ring)
        watch.handle(.reorder, window: w1)
        watch.handle(.reorder, window: w2)
        watch.handle(.hide, window: w1)
        #expect(calls() == ["ring.hide w1"])
        endTurn()
        #expect(calls() == ["ring.hide w1", "ring.restack w2"])
    }

    /// The mark and overflow mark take no hide: a reorder then a
    /// hide still owes them their re-assert.
    @Test("a hide drops only the consumers that took it")
    func hideKeepsConsumersWithoutAHide() {
        let (watch, endTurn, calls) = turnWatch(markHides: false)
        watch.request([w1], for: .mark)
        watch.request([w1], for: .ring)
        watch.handle(.reorder, window: w1)
        watch.handle(.hide, window: w1)
        endTurn()
        #expect(calls() == ["ring.hide w1", "mark.restack w1"])
    }

    @Test("a reorder after a hide in the turn re-owes every consumer")
    func reorderAfterHideReowes() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1], for: .ring)
        watch.handle(.reorder, window: w1)
        watch.handle(.hide, window: w1)
        watch.handle(.reorder, window: w1)
        endTurn()
        #expect(calls() == ["ring.hide w1", "ring.restack w1"])
    }

    @Test("an unhide after a hide still restacks")
    func unhideAfterHideRestacks() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1], for: .ring)
        watch.handle(.hide, window: w1)
        watch.handle(.unhide, window: w1)
        endTurn()
        #expect(calls() == ["ring.hide w1", "ring.restack w1"])
    }

    @Test("a window no longer heard at the turn's end restacks nothing")
    func dropStaysDropped() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1], for: .ring)
        watch.handle(.reorder, window: w1)
        watch.request([], for: .ring)
        endTurn()
        #expect(calls().isEmpty)
    }

    @Test("a stop forgets the turn's owed restacks")
    func stopForgets() {
        let (watch, endTurn, calls) = turnWatch()
        watch.request([w1], for: .ring)
        watch.handle(.reorder, window: w1)
        watch.stop()
        watch.request([w1], for: .ring)
        endTurn()
        #expect(calls().isEmpty)
    }
}

/// The live turn end the bootstrap wires (#2659): work waits for
/// the main run loop's turn to end, and work queued while it
/// drains runs in the same drain.
@Suite("Main run loop turn end")
@MainActor
struct MainRunLoopTurnEndTests {
    @Test("work runs when the turn ends, nested work included")
    func runsAtTheTurnsEnd() {
        @MainActor final class Box { var ran: [String] = [] }
        let box = Box()
        MainRunLoopTurnEnd.schedule {
            box.ran.append("first")
            MainRunLoopTurnEnd.schedule { box.ran.append("nested") }
        }
        #expect(box.ran.isEmpty)
        // A timer gives the run loop a source, or it returns at once
        // without a turn.
        let tick = Timer(timeInterval: 0.01, repeats: false) { _ in }
        RunLoop.main.add(tick, forMode: .default)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        #expect(box.ran == ["first", "nested"])
    }
}
