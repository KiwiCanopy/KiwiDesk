import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #2002 return measured from the episode's OPENING, and the
/// landing it owes: a press is the user acting only from the
/// instant the distrust opened (the close click itself comes
/// first), and the owed switch lifts the Space's float layer like
/// every follow-shaped landing (#412/#1727).
@Suite("Delayed close return: opening and landing (#2002)", .serialized)
@MainActor
struct DelayedCloseOpeningTests {
    let fx = DelayedCloseFixture()
    private let opened = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ core: KiwiCore, _ offset: TimeInterval) {
        let instant = opened.addingTimeInterval(offset)
        core.wallClock = { instant }
    }

    /// The close button's click lands before the episode opens and
    /// is no stand-down; a one-second "recent press" reading
    /// would take it for one.
    @Test("The close click before the episode keeps the return")
    func closeClickKeepsTheReturn() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        at(core, -0.1)
        core.lastLeftClick = (core.wallClock(), .zero, fx.closing)
        at(core, 0)
        fx.refuse(core)
        at(core, 0.07)
        fx.keySuccessor(core)
        at(core, 0.8)
        fx.confirmClose(core)
        fx.expectReturned(core, log)
    }

    /// A Dock or Window-menu pick keys the successor ahead of its
    /// report, inside the episode: measured from the note, it
    /// would be missed.
    @Test("A press between the opening and the report stands down")
    func pressBeforeTheReportStandsDown() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        at(core, 0)
        fx.refuse(core)
        at(core, 0.03)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        at(core, 0.07)
        fx.keySuccessor(core)
        at(core, 0.8)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("return stood down (a press)"))
    }

    /// A float on the owed Space rises above its tiled plane at
    /// the landing; its element is this process's application,
    /// whose raise is unsupported and moves nothing (the
    /// `FollowSwitchFloatRaiseTests` instrument).
    @Test("The owed switch lifts the Space's float layer")
    func owedSwitchLiftsFloats() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        let pid = ProcessInfo.processInfo.processIdentifier
        let float = WindowID(6)
        core.state.windows.upsert(
            ManagedWindow(
                id: float,
                pid: pid,
                appName: "Float",
                frame: CGRect(x: 100, y: 100, width: 300, height: 200),
                isFloating: true
            )
        )
        core.state.workspaces.add(float, to: "1")
        core.state.workspaces.focus(fx.closing, in: "1")
        core.eventLoop.elements[pid] = [
            float: AXUIElementCreateApplication(pid)
        ]
        fx.refuse(core)
        fx.keySuccessor(core)
        #expect(core.zOrderRaiseEchoes[float] == nil)
        fx.confirmClose(core)
        fx.expectReturned(core, log)
        #expect(core.zOrderRaiseEchoes[float] != nil)
    }
}
