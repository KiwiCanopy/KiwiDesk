import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A detection flip's float placement waits for the hand to rest
/// (#2627), as the #804 gate holds an ambient pass: the window is
/// owed, never its frame, so the pass that runs places it only
/// where it is still a float at the frame it was owed at. The
/// hand, the clock and the re-ask are driven by hand.
@Suite("Detected float placement waits for the hand", .serialized)
@MainActor
struct DetectedFloatPlacementHoldTests {
    private let slot = CGRect(x: 40, y: 60, width: 300, height: 900)
    private let window = WindowID(2)

    @MainActor
    private final class Desk {
        let core: KiwiCore
        var now: TimeInterval = 100
        var stillFor: TimeInterval = 10
        var polls: [@MainActor () -> Void] = []
        var frames: [WindowID: CGRect] = [:]
        var lines: [String] = []

        init(slot: CGRect, window: WindowID) {
            let dir =
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-tests-\(UUID().uuidString)"
                )
            core = makeTestCore(configDirectory: dir)
            let bounds = CGRect(x: 0, y: 0, width: 1600, height: 1000)
            core.tiler.visibleBounds = { _ in bounds }
            core.tiler.allScreenBounds = { [bounds] }
            core.tiler.settings.floatPlacement = .center
            core.execute(
                "set_mode",
                args: [.string("1"), .string("bsp")]
            )
            for index in 1...2 {
                core.state.apply(
                    .windowCreated(
                        ManagedWindow(
                            id: WindowID(UInt32(index)),
                            pid: 1,
                            appName: "A"
                        )
                    )
                )
            }
            core.state.apply(.windowResized(window, slot))
            core.state.apply(.windowFocused(window))
            core.tiler.settings.animations.onRelayout = true
            core.tiler.animation.isEnabled = false
            core.tiler.animation.apply = { [unowned self] id, frame, _ in
                self.frames[id] = frame
            }
            let gate = core.tiler.motionGate
            gate.clock = { [unowned self] in self.now }
            gate.schedule = { [unowned self] _, work in
                self.polls.append(work)
            }
            gate.quiescence.sinceMouseMoved = { [unowned self] in
                self.stillFor
            }
            gate.onLog = { _ in }
            core.onLog = { [unowned self] in self.lines.append($0) }
        }

        var gate: MotionGate { core.tiler.motionGate }

        func flip(_ id: WindowID, _ floating: Bool) {
            core.handle(.windowFloatChanged(id, isFloating: floating))
        }

        /// The hand comes to rest and the gate re-asks.
        func rest() {
            stillFor = InputQuiescence.quietGap
            let due = polls
            polls = []
            for work in due { work() }
        }

        var held: Bool {
            lines.contains { $0.hasPrefix("direct write held") }
        }

        func isCentred(_ id: WindowID) -> Bool {
            guard let frame = frames[id],
                let region = core.floatGrowBounds(of: id)
            else { return false }
            return abs(frame.midX - region.midX) < 0.001
                && abs(frame.midY - region.midY) < 0.001
        }
    }

    private func held() -> Desk {
        let desk = Desk(slot: slot, window: window)
        desk.stillFor = 0.05
        desk.frames = [:]
        desk.flip(window, true)
        return desk
    }

    @Test("a flip under a moving mouse is owed, then placed at rest")
    func movingMouseOwes() {
        let desk = held()
        #expect(desk.frames[window] == nil)
        #expect(desk.gate.owedWrites[window] != nil)
        desk.rest()
        #expect(desk.isCentred(window))
        #expect(desk.gate.owedWrites.isEmpty)
    }

    @Test("a flip with the hand at rest is placed at once")
    func restingHandPlaces() {
        let desk = Desk(slot: slot, window: window)
        desk.flip(window, true)
        #expect(desk.isCentred(window))
        #expect(!desk.held)
    }

    /// A flip under a control's own scope is the user's: never held.
    @Test("a flip under user motion is placed at once")
    func userFlipPlaces() {
        let desk = Desk(slot: slot, window: window)
        desk.stillFor = 0.05
        desk.core.withUserMotion { desk.flip(window, true) }
        #expect(desk.isCentred(window))
        #expect(!desk.held)
    }

    @Test("a control's own pass pays the owed placement")
    func userPassPays() {
        let desk = held()
        desk.core.withUserMotion { desk.core.retile() }
        #expect(desk.isCentred(window))
        #expect(desk.gate.owedWrites.isEmpty)
    }

    /// The user's own act owns the frame: a drag from its first
    /// move, a flick whose moves land after the release (#1798) at
    /// its end, and any frame written under user motion.
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
            desk.core.handleDragMove(window, start: slot, frame: moved)
            desk.core.tiler.dragExemptWindow = nil
        case .dragEnd:
            desk.core.handleDragEnd(window, start: slot, frame: moved)
        case .write:
            desk.core.withUserMotion {
                desk.core.tiler.applyFrame(
                    window,
                    from: slot,
                    to: moved,
                    animated: false
                )
            }
        }
        desk.frames = [:]
        desk.rest()
        #expect(desk.frames[window] == nil)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    @Test("a window tiled again while owed is not placed")
    func tiledWhileOwedSkips() {
        let desk = held()
        desk.flip(window, false)
        desk.rest()
        // A placement would consume the frame the tile filed.
        #expect(desk.core.state.floatFrames[window] != nil)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    enum StandDown: CaseIterable {
        case dragged, fullscreen, deferred
    }

    @Test(
        "a window no placement may reach while owed keeps its frame",
        arguments: StandDown.allCases
    )
    func standDownWhileOwedSkips(_ standDown: StandDown) {
        let desk = held()
        switch standDown {
        case .dragged: desk.core.tiler.dragExemptWindow = window
        case .fullscreen:
            desk.core.state.windows.setFullscreen(window, true)
        case .deferred: desk.core.defersEventRetiles = true
        }
        desk.rest()
        #expect(desk.frames[window] == nil)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    /// A switch away is a user pass: it pays before its own park,
    /// so the placement is the frame the Space keeps for the return.
    @Test("a switch away pays the debt before it parks")
    func switchAwayPaysFirst() throws {
        let desk = held()
        desk.core.withUserMotion {
            _ = desk.core.execute("focus_space", args: [.string("2")])
        }
        #expect(desk.gate.owedWrites.isEmpty)
        let kept = try #require(desk.core.tiler.stashedFrames[window])
        #expect(kept.width == FloatPlacement.longFloor)
    }

    /// A frame that moves with no drag — our own echo, or the app
    /// answering a refused ask (#677) — decides nothing.
    @Test("a frame moved with no drag still takes the placement")
    func undraggedMoveKeepsTheDebt() {
        let desk = held()
        let clamped = CGRect(x: 40, y: 60, width: 420, height: 880)
        desk.core.state.apply(.windowMoved(window, clamped))
        desk.rest()
        #expect(desk.isCentred(window))
    }

    /// A write owed while no pass is owed owes one, or nothing would
    /// release it until an unrelated pass.
    @Test("a write owed with no pass owed arms its own release")
    func owedAloneArmsTheRelease() {
        let desk = Desk(slot: slot, window: window)
        desk.core.state.setFloating(window, true)
        desk.stillFor = 0.05
        desk.frames = [:]
        #expect(desk.gate.owed == nil)
        desk.core.placeDetectedFloat(window)
        #expect(desk.gate.owed != nil)
        desk.rest()
        #expect(desk.isCentred(window))
    }

    @Test("a tab switch while owed carries the debt to the new id")
    func rekeyCarriesTheDebt() {
        let desk = held()
        let tab = WindowID(7)
        desk.core.handle(.windowRekeyed(window, tab))
        #expect(desk.gate.owedWrites[window] == nil)
        #expect(desk.gate.owedWrites[tab] != nil)
        desk.rest()
        #expect(desk.isCentred(tab))
    }

    /// `placeFloating` refuses an untracked window too, so this
    /// holds that the debt is dropped, not which clause drops it.
    @Test("a window closed while owed is forgotten")
    func closedWhileOwedForgets() {
        let desk = held()
        desk.core.state.apply(
            .windowDestroyed(window, wasMinimized: false)
        )
        desk.rest()
        #expect(desk.frames[window] == nil)
        #expect(desk.gate.owedWrites.isEmpty)
    }

    @Test("a flip on an unshown Space seeds at once")
    func unshownSpaceSeedsAtOnce() throws {
        let desk = Desk(slot: slot, window: window)
        desk.core.execute(
            "move_to_space",
            args: [.string("2"), .number(Double(window.raw))]
        )
        desk.stillFor = 0.05
        desk.flip(window, true)
        #expect(desk.gate.owedWrites.isEmpty)
        let seed = try #require(desk.core.tiler.stashedFrames[window])
        #expect(seed.width == FloatPlacement.longFloor)
    }

    @Test("stopping forgets the owed placements")
    func dropAllForgets() {
        let desk = held()
        desk.gate.dropAll()
        #expect(desk.gate.owedWrites.isEmpty)
    }
}
