import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The input-quiescence gate (#804 ▸ Ruling): an ambient layout
/// pass and a user call's late tail wait for buttons up and a quiet
/// mouse, past the patience bound for buttons up alone; what waits
/// is the pass, owed and re-run against the state as it then is; a
/// pass a control makes now runs and pays the debt. The hand, the
/// clock and the re-ask are driven by hand; frames are read off the
/// applier's `issued` tee.
@Suite("Motion gate (#804)", .serialized)
@MainActor
struct MotionGateTests {
    @MainActor
    private final class Desk {
        let core: KiwiCore
        var now: TimeInterval = 100
        var buttons = false
        var stillFor: TimeInterval = 10
        var polls: [@MainActor () -> Void] = []
        var issued: [WindowID] = []

        init() throws {
            typealias F = BootRestoreFixture
            let windows = (1...2).map {
                F.Window(
                    id: WindowID(UInt32($0)),
                    space: F.shown,
                    frame: CGRect(x: 0, y: 0, width: 10, height: 10)
                )
            }
            core = try #require(F.processA(windows))
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

        func poll() {
            let due = polls
            polls = []
            for work in due { work() }
        }
    }

    @Test("An ambient pass with the hand at rest lays out")
    func restingHandPasses() throws {
        let desk = try Desk()
        desk.core.retile()
        #expect(!desk.issued.isEmpty)
        #expect(desk.gate.owed == nil)
    }

    @Test("An ambient pass under a moving mouse is owed, then runs")
    func movingMouseOwes() throws {
        let desk = try Desk()
        desk.stillFor = 0.05
        desk.core.retile()
        #expect(desk.issued.isEmpty)
        #expect(desk.gate.owed != nil)
        desk.poll()
        #expect(desk.issued.isEmpty)
        desk.stillFor = InputQuiescence.quietGap
        desk.poll()
        #expect(!desk.issued.isEmpty)
        #expect(desk.gate.owed == nil)
    }

    @Test("A held button holds past patience; buttons up alone then do")
    func buttonsHoldPastPatience() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.buttons = true
        desk.core.retile()
        desk.now += InputQuiescence.patience + 1
        desk.poll()
        #expect(desk.issued.isEmpty)
        desk.buttons = false
        desk.poll()
        #expect(!desk.issued.isEmpty)
    }

    /// The owed pass is paid by the admitted one, which re-derived
    /// every frame — nothing stale is sent afterwards.
    @Test("A control's own pass runs and pays the debt")
    func userPassPays() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile()
        #expect(desk.issued.isEmpty)
        desk.core.withUserMotion { desk.core.retile() }
        let sent = desk.issued
        #expect(!sent.isEmpty)
        #expect(desk.gate.owed == nil)
        desk.stillFor = 10
        desk.poll()
        #expect(desk.issued == sent)
    }

    @Test("A user call's late tail waits like ambient motion")
    func lateTailWaits() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.tiler.applier.motion.with(
            .user(pressedAt: Date(), late: true)
        ) {
            desk.core.retile()
        }
        #expect(desk.issued.isEmpty)
        #expect(desk.gate.owed != nil)
    }

    /// A held pass sends nothing, so it stamps no placement and
    /// asks no size; both land with the pass that sends.
    @Test("A held pass stamps and asks nothing until it runs")
    func heldPassRecordsNothing() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile()
        let window = WindowID(1)
        #expect(desk.core.tiler.placements.recent(window) == nil)
        #expect(desk.core.tiler.boundLearner.lastAsks[window] == nil)
        desk.stillFor = 10
        desk.poll()
        #expect(desk.core.tiler.placements.recent(window) != nil)
        #expect(desk.core.tiler.boundLearner.lastAsks[window] != nil)
    }

    @Test("Owed passes merge: the stronger pass, a spring promise twice")
    func owedPassesMerge() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile(pass: .apply, sizing: .allSpringSized)
        desk.core.retile(pass: .event, sizing: .mayInstantSize)
        #expect(desk.gate.owed?.pass == .apply)
        #expect(desk.gate.owed?.sizing == .mayInstantSize)
    }

    /// Holding a switch would split the desk (owner, 2026-10-06).
    @Test("A switch the user watches is never held")
    func switchNeverWaits() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.spaceSwitchRetile(asSwitch: true)
        #expect(!desk.issued.isEmpty)
        #expect(desk.gate.owed == nil)
    }

    /// Boot, the wake replay and a sweep activate a Space too, but
    /// nobody is watching a switch: they wait like ambient motion.
    @Test("A boot or wake activation waits for the hand")
    func activationWaits() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.spaceSwitchRetile(asSwitch: false)
        #expect(desk.issued.isEmpty)
        #expect(desk.gate.owed?.pass == .reissue)
    }

    /// What was owed rides the admitted pass, so a weaker pass
    /// never drops an apply's probe or a new window's entrance.
    @Test("An admitted pass carries the debt")
    func admittedPassCarriesDebt() throws {
        let desk = try Desk()
        desk.stillFor = 0
        let owed = MotionGate.Owed(
            animated: nil,
            pass: .apply,
            newlyCreatedWindow: WindowID(2),
            sizing: .mayInstantSize
        )
        #expect(desk.gate.admit(owed) == nil)
        let run = desk.core.withUserMotion {
            desk.gate.admit(
                MotionGate.Owed(
                    animated: true,
                    pass: .event,
                    newlyCreatedWindow: nil,
                    sizing: .mayInstantSize
                )
            )
        }
        #expect(run?.pass == .apply)
        #expect(run?.newlyCreatedWindow == WindowID(2))
        #expect(desk.gate.owed == nil)
    }

    /// The restore orders the frames the pass draws (#153), so it
    /// waits for an owed pass as for an animation.
    @Test("A z-order restore waits for the owed pass")
    func restoreWaitsForOwedPass() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile()
        desk.core.scheduleZOrderRestore()
        #expect(desk.core.pendingZOrderRestore)
        desk.stillFor = 10
        desk.poll()
        #expect(!desk.core.pendingZOrderRestore)
    }

    /// A control's own pass that pays the debt runs the restore
    /// that waited, even when it animates nothing.
    @Test("A user pass paying the debt runs a waiting restore")
    func userPassRunsWaitingRestore() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile()
        desk.core.scheduleZOrderRestore()
        #expect(desk.core.pendingZOrderRestore)
        desk.core.withUserMotion { desk.core.retile() }
        #expect(!desk.core.pendingZOrderRestore)
    }

    @Test("Stopping forgets the debt")
    func dropForgets() throws {
        let desk = try Desk()
        desk.stillFor = 0
        desk.core.retile()
        desk.gate.dropAll()
        desk.stillFor = 10
        desk.poll()
        #expect(desk.issued.isEmpty)
    }
}
