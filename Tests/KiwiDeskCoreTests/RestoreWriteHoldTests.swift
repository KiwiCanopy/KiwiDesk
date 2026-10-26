import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The snapshot restore's direct frame writes wait for the hand to
/// rest (#2626), as the #804 gate holds an ambient pass: the window
/// is owed, never its frame, and the payment re-reads the frame
/// from the replay's snapshot under the screens it was owed on.
/// The hand, the clock and the re-ask are driven by hand; every
/// frame sent is logged, so the saved frame is told from a slot.
@Suite("Restore writes wait for the hand", .serialized)
@MainActor
struct RestoreWriteHoldTests {
    private let window = WindowID(3)
    private let start = CGRect(x: 100, y: 100, width: 500, height: 400)
    private let saved = CGRect(x: 300, y: 200, width: 640, height: 480)

    @MainActor
    private final class Desk {
        let core: KiwiCore
        var stillFor: TimeInterval = 10
        var polls: [@MainActor () -> Void] = []
        var sent: [WindowID: [CGRect]] = [:]

        init(window: WindowID, start: CGRect) {
            core = makeTestCore()
            let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
            core.tiler.visibleBounds = { _ in bounds }
            core.tiler.allScreenBounds = { [bounds] }
            core.tiler.animation.isEnabled = false
            core.tiler.animation.apply = { [unowned self] id, frame, _ in
                self.sent[id, default: []].append(frame)
            }
            core.tiler.applier.issued = { [unowned self] id, frame in
                self.sent[id, default: []].append(frame)
            }
            core.tiler.applier.clock = { 0 }
            core.execute("set_mode", args: [.string("1"), .string("bsp")])
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: window, pid: 1, appName: "A")
                )
            )
            core.state.apply(.windowResized(window, start))
            let gate = core.tiler.motionGate
            gate.clock = { 100 }
            gate.schedule = { [unowned self] _, work in
                self.polls.append(work)
            }
            gate.quiescence.sinceMouseMoved = { [unowned self] in
                self.stillFor
            }
            gate.onLog = { _ in }
            core.onLog = { _ in }
        }

        var gate: MotionGate { core.tiler.motionGate }

        func snapshot(
            _ id: WindowID,
            at frame: CGRect,
            mode: LayoutMode = .bsp
        ) -> StateSnapshot {
            StateSnapshot(
                windows: [.init(id: id, frame: frame)],
                spaces: [
                    .init(
                        space: Space(
                            id: SpaceID(1),
                            mode: mode,
                            windows: [id],
                            focused: id
                        )
                    )
                ],
                activeSpace: "1"
            )
        }

        /// How many times `frame` was sent to `id`.
        func sends(_ frame: CGRect, to id: WindowID) -> Int {
            sent[id, default: []].filter { $0 == frame }.count
        }

        /// The hand comes to rest and the gate re-asks.
        func rest() {
            stillFor = InputQuiescence.quietGap
            let due = polls
            polls = []
            for work in due { work() }
        }
    }

    /// A replay under a moving hand, its write owed.
    private func held() -> Desk {
        let desk = Desk(window: window, start: start)
        desk.stillFor = 0.05
        desk.core.restore(desk.snapshot(window, at: saved))
        return desk
    }

    /// The same replay on a floating Space, its window a float.
    private func heldFloat() -> Desk {
        let desk = Desk(window: window, start: start)
        desk.core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        desk.stillFor = 0.05
        desk.core.restore(
            desk.snapshot(window, at: saved, mode: .floating)
        )
        return desk
    }

    @Test("a replay under a moving mouse is owed, then written at rest")
    func movingMouseOwes() {
        let desk = held()
        #expect(desk.sends(saved, to: window) == 0)
        #expect(desk.gate.owedWrites[window] == [.restore])
        desk.rest()
        #expect(desk.sends(saved, to: window) == 1)
        #expect(desk.gate.owedWrites.isEmpty)
        #expect(desk.core.restoreDebt == nil)
    }

    @Test("a replay with the hand at rest writes at once")
    func restingHandWrites() {
        let desk = Desk(window: window, start: start)
        desk.core.restore(desk.snapshot(window, at: saved))
        #expect(desk.sends(saved, to: window) == 1)
        #expect(desk.gate.owedWrites.isEmpty)
        #expect(desk.core.restoreDebt == nil)
    }

    @Test("a control's own pass pays the owed write")
    func userPassPays() {
        let desk = held()
        desk.core.withUserMotion { desk.core.retile() }
        #expect(desk.sends(saved, to: window) == 1)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    /// A newer replay's frame is the one paid, never the older one's.
    @Test("a newer replay supersedes the owed one")
    func newerReplaySupersedes() {
        let desk = held()
        let newer = CGRect(x: 700, y: 100, width: 400, height: 300)
        desk.core.restore(desk.snapshot(window, at: newer))
        desk.rest()
        #expect(desk.sends(newer, to: window) == 1)
        #expect(desk.sends(saved, to: window) == 0)
    }

    /// A float's seed rides the held pass (#1864): its payment
    /// declines, so the saved frame is sent once.
    @Test("a held float is delivered once, by its seed")
    func heldFloatSendsOnce() {
        let desk = heldFloat()
        #expect(desk.sends(saved, to: window) == 0)
        #expect(desk.gate.owedWrites[window] == [.restore])
        desk.rest()
        #expect(desk.sends(saved, to: window) == 1)
    }

    /// A move that forgets the seed (#412) is not paid over.
    @Test("a held float moved by its app keeps the move")
    func heldFloatMovedKeeps() {
        let desk = heldFloat()
        let moved = CGRect(x: 500, y: 300, width: 640, height: 480)
        desk.core.handle(.windowMoved(window, moved))
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }

    @Test("a tab switch while owed carries the debt to the new id")
    func rekeyCarriesTheDebt() {
        let desk = held()
        let tab = WindowID(7)
        desk.core.handle(.windowRekeyed(window, tab))
        #expect(desk.gate.owedWrites[tab] == [.restore])
        desk.rest()
        #expect(desk.sends(saved, to: tab) == 1)
    }

    @Test("a newer replay without the window drops the owed write")
    func newerReplayWithoutTheWindowDrops() {
        let desk = held()
        let other = WindowID(9)
        desk.core.restore(desk.snapshot(other, at: saved))
        #expect(desk.gate.owedWrites[window] == nil)
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }

    /// What supersedes the replay voids what it owed: a new rest,
    /// a stop, a discarded arrangement.
    enum Voiding: CaseIterable {
        case rest, stop, drop
    }

    @Test(
        "a voided replay's owed write is never paid",
        arguments: Voiding.allCases
    )
    func voidedReplayDrops(_ void: Voiding) {
        let desk = held()
        switch void {
        case .rest: desk.core.sleepWake.systemWillRest(.direct)
        case .stop: desk.core.stop()
        case .drop: desk.core.discardSavedArrangement()
        }
        #expect(desk.gate.owedWrites[window] == nil)
        #expect(desk.core.restoreDebt == nil)
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }

    /// The user's own act owns the frame: a drag from its first
    /// move, a flick at its end, any frame written under user
    /// motion.
    enum UserAct: CaseIterable {
        case dragMove, dragEnd, write
    }

    @Test(
        "a window the user moved while owed keeps its frame",
        arguments: UserAct.allCases
    )
    func userActWhileOwedKeeps(_ act: UserAct) {
        let desk = held()
        let moved = CGRect(x: 500, y: 300, width: 640, height: 480)
        switch act {
        case .dragMove:
            desk.core.handleDragMove(window, start: start, frame: moved)
            desk.core.tiler.dragExemptWindow = nil
        case .dragEnd:
            desk.core.handleDragEnd(window, start: start, frame: moved)
        case .write:
            desk.core.withUserMotion {
                desk.core.tiler.setFrame(window, moved)
            }
        }
        #expect(desk.gate.owedWrites[window] == nil)
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }

    /// The frame is re-read at payment: a changed screen set
    /// (#633) or a window filed elsewhere meanwhile owes nothing.
    @Test("a changed screen set drops the owed write")
    func changedScreensDrop() {
        let desk = held()
        desk.core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(42),
                name: "Added",
                frame: CGRect(x: 1600, y: 0, width: 1920, height: 1080)
            )
        )
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    /// Two identical monitors share a fingerprint: losing one is
    /// a change a set would swallow (#633).
    @Test("the screens compare as a multiset")
    func screensCompareAsMultiset() {
        let one = ["Studio:0,0,1920,1080"]
        #expect(!SleepWakeManager.sameTopology(one, one + one))
        #expect(SleepWakeManager.sameTopology(["b", "a"], ["a", "b"]))
    }

    @Test("a window moved to another Space while owed is not written")
    func refiledWhileOwedSkips() {
        let desk = held()
        desk.core.state.workspaces.ensureSpace(SpaceID(2))
        desk.core.state.workspaces.add(window, to: SpaceID(2))
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }

    @Test("a window closed while owed is not written")
    func closedWhileOwedSkips() {
        let desk = held()
        desk.core.state.apply(.windowDestroyed(window, wasMinimized: false))
        desk.rest()
        #expect(desk.sends(saved, to: window) == 0)
    }
}
