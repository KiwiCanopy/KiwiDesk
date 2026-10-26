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

    /// Moved by hand or by its app while owed: that frame stands.
    @Test("a window moved while owed keeps its frame")
    func movedWhileOwedKeeps() {
        let desk = held()
        let moved = CGRect(x: 500, y: 300, width: 640, height: 480)
        desk.core.state.apply(.windowMoved(window, moved))
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

    /// Our own echo landing during the hold is no move: the guard
    /// is the frame we last sent, never the state frame at the flip.
    @Test("our own echo landing while owed keeps the debt")
    func ownEchoKeepsTheDebt() throws {
        let desk = Desk(slot: slot, window: window)
        // An instant pass at rest sends the slot through the applier,
        // which records it as commanded; its echo has not landed.
        desk.core.tiler.settings.animations.onRelayout = false
        desk.core.retile()
        desk.core.tiler.settings.animations.onRelayout = true
        desk.stillFor = 0.05
        desk.frames = [:]
        desk.flip(window, true)
        guard case .floatPlacement(let sent)? = desk.gate.owedWrites[window]
        else {
            Issue.record("no write owed")
            return
        }
        try #require(!TilingEngine.close(sent, to: slot))
        desk.core.state.apply(.windowMoved(window, sent))
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
