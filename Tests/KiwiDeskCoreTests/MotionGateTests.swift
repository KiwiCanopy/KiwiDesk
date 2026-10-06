import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The input-quiescence gate (#804 ▸ Ruling): ambient motion and a
/// late user tail wait for buttons up and a quiet mouse, past the
/// patience bound for buttons up alone; motion a control is making
/// now passes and discharges what was held; a held move stamps and
/// asks nothing until it is sent. The hand, the clock and the
/// re-ask are all driven by hand.
@Suite("Motion gate (#804)", .serialized)
@MainActor
struct MotionGateTests {
    @MainActor
    private final class Desk {
        let core = makeTestCore()
        var now: TimeInterval = 100
        var buttons = false
        var stillFor: TimeInterval = 10
        var polls: [@MainActor () -> Void] = []
        var issued: [WindowID] = []
        let window = WindowID(7)
        let frame = CGRect(x: 10, y: 40, width: 500, height: 400)

        init() {
            let gate = core.tiler.motionGate
            gate.clock = { [unowned self] in self.now }
            gate.schedule = { [unowned self] _, work in
                self.polls.append(work)
            }
            gate.quiescence.buttonsDown = { [unowned self] in
                self.buttons
            }
            gate.quiescence.sinceMouseMoved = { [unowned self] in
                self.stillFor
            }
            gate.onLog = { _ in }
            core.tiler.applier.issued = { [unowned self] id, _ in
                self.issued.append(id)
            }
        }

        var gate: MotionGate { core.tiler.motionGate }

        func set() { core.tiler.setFrame(window, frame) }

        /// Runs the pending re-asks once.
        func poll() {
            let due = polls
            polls = []
            for work in due { work() }
        }
    }

    @Test("Ambient motion with the hand at rest passes")
    func restingHandPasses() {
        let desk = Desk()
        desk.set()
        #expect(desk.issued == [desk.window])
        #expect(!desk.gate.isHolding(desk.window))
    }

    @Test("Ambient motion under a moving mouse waits, then lands")
    func movingMouseHolds() {
        let desk = Desk()
        desk.stillFor = 0.05
        desk.set()
        #expect(desk.issued.isEmpty)
        #expect(desk.gate.isHolding(desk.window))
        desk.poll()
        #expect(desk.issued.isEmpty)
        desk.stillFor = InputQuiescence.quietGap
        desk.poll()
        #expect(desk.issued == [desk.window])
        #expect(!desk.gate.isHolding(desk.window))
    }

    @Test("A held button holds past patience; buttons up alone then do")
    func buttonsHoldPastPatience() {
        let desk = Desk()
        desk.stillFor = 0
        desk.buttons = true
        desk.set()
        desk.now += InputQuiescence.patience + 1
        desk.poll()
        #expect(desk.issued.isEmpty)
        desk.buttons = false
        desk.poll()
        #expect(desk.issued == [desk.window])
    }

    @Test("A control's own motion passes and discharges the held")
    func userPassDischarges() {
        let desk = Desk()
        desk.stillFor = 0
        desk.set()
        #expect(desk.issued.isEmpty)
        let other = WindowID(8)
        desk.core.withUserMotion {
            desk.core.tiler.setFrame(other, desk.frame)
        }
        #expect(Set(desk.issued) == [desk.window, other])
    }

    @Test("A user call's late tail waits like ambient motion")
    func lateTailWaits() {
        let desk = Desk()
        desk.stillFor = 0
        desk.core.tiler.applier.motion.with(
            .user(pressedAt: Date(), late: true)
        ) {
            desk.set()
        }
        #expect(desk.issued.isEmpty)
        #expect(desk.gate.isHolding(desk.window))
    }

    @Test("A held move stamps no placement until it is sent")
    func heldMoveStampsNothing() {
        let desk = Desk()
        desk.stillFor = 0
        desk.set()
        #expect(desk.core.tiler.placements.recent(desk.window) == nil)
        desk.stillFor = 10
        desk.poll()
        #expect(desk.core.tiler.placements.recent(desk.window) != nil)
    }

    @Test("Stopping drops what the gate held")
    func dropForgets() {
        let desk = Desk()
        desk.stillFor = 0
        desk.set()
        desk.gate.dropAll()
        desk.stillFor = 10
        desk.poll()
        #expect(desk.issued.isEmpty)
    }
}
