import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #2002 let-outs that leave today's behaviour by never
/// noting a debt, or by retiring it before the confirmation: each
/// reds when its clause in `KiwiCore+DelayedCloseReturn` (or the
/// distrust machine's recorded cause / episode end) is removed.
@Suite("Delayed close return: let-outs (#2002)", .serialized)
@MainActor
struct DelayedCloseLetOutTests {
    let fx = DelayedCloseFixture()

    /// No episode: the app never reported the close, so the
    /// #1930 order stands — the focus moved first, nothing raises.
    @Test("An undistrusted close after the focus moved is untouched")
    func undistrustedCloseUntouched() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.keySuccessor(core)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(!log.has("close distrust: w"))
    }

    /// An expected-absence arm's episode is not a delayed close —
    /// judged on the cause recorded at the opening, so the arm
    /// closing before the report changes nothing.
    @Test("A fullscreen-transition episode notes no debt")
    func expectedAbsenceNotesNothing() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        core.eventLoop.detectedFullscreen[fx.closing] = true
        let closing = fx.closing
        let refused = core.eventLoop.refusesExpectedRemoval(
            closing,
            pid: fx.app,
            app: AppRef(bundleID: "com.example.app", name: "App"),
            census: { [closing] }
        )
        #expect(refused)
        core.eventLoop.detectedFullscreen[fx.closing] = nil
        fx.keySuccessor(core)
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
    }

    @Test("A successor on the closed window's own Space is untouched")
    func sameSpaceSuccessorUntouched() {
        let (core, log) = fx.makeCore(sameSpace: true)
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core, follow: false)
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.activeSpace?.focused == fx.successor)
        #expect(!log.has("close-return: raising"))
        #expect(!log.has("confirmed late"))
    }

    /// The close that lands while it still holds the focus raises
    /// the fallback as it always did, with no debt involved.
    @Test("An undelayed close of the focus raises as today")
    func undelayedCloseRaises() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.confirmClose(core)
        fx.expectReturned(core, log)
        #expect(!log.has("close distrust: w"))
    }

    @Test("Our own raise's echo notes no debt")
    func selfEchoNotesNothing() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        core.stampSelfRaise(fx.successor, now: core.wallClock())
        fx.keySuccessor(core)
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        #expect(!log.has("confirmed late"))
    }

    @Test("A report a click reached notes no debt")
    func clickedReportNotesNothing() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        core.lastLeftClick = (core.wallClock(), .zero, fx.successor)
        fx.keySuccessor(core)
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        #expect(!log.has("confirmed late"))
    }

    @Test("A third honored report voids the debt")
    func thirdReportVoids() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        let other = WindowID(5)
        core.state.windows.upsert(
            ManagedWindow(id: other, pid: 80, appName: "App80")
        )
        core.state.workspaces.add(other, to: "2")
        core.handle(.windowFocused(other))
        core.deferred.cancel(.focusFollow)
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        #expect(!log.has("confirmed late"))
        #expect(!log.has("close-return: raising"))
    }

    /// A landing float's raise echo is ours, not the user moving
    /// on: the debt survives it.
    @Test("Our own raise's echo of a third window keeps the debt")
    func selfEchoKeepsTheDebt() {
        let (core, _) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        let other = WindowID(5)
        core.state.windows.upsert(
            ManagedWindow(id: other, pid: 80, appName: "App80")
        )
        core.state.workspaces.add(other, to: "2")
        core.stampSelfRaise(other, now: core.wallClock())
        core.handle(.windowFocused(other))
        core.deferred.cancel(.focusFollow)
        #expect(core.delayedCloseDebt != nil)
    }

    /// The episode ending without a close takes the debt with it,
    /// so a later genuine close inside the bound heals nothing.
    @Test("A re-listed window retires the debt with its episode")
    func relistedRetires() {
        let (core, log) = fx.makeCore()
        defer { fx.tearDown() }
        fx.refuse(core)
        fx.keySuccessor(core)
        core.eventLoop.endRemovalEpisodes(relisted: [fx.closing])
        #expect(core.delayedCloseDebt == nil)
        fx.confirmClose(core)
        fx.expectUntouched(core, log)
        #expect(log.has("debt retired — re-listed"))
    }

    @Test("A re-key of either window retires the debt")
    func rekeyRetires() {
        for rekeyed in [fx.successor, fx.closing] {
            let (core, log) = fx.makeCore()
            defer { fx.tearDown() }
            fx.refuse(core)
            fx.keySuccessor(core)
            core.handle(.windowRekeyed(rekeyed, WindowID(9)))
            #expect(core.delayedCloseDebt == nil, "w\(rekeyed.raw)")
            #expect(log.has("debt retired — re-keyed"))
        }
    }
}
