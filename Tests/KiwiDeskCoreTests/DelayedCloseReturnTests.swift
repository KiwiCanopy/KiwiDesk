import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The delayed-close return (#2002): a close the #1157 distrust
/// refused is confirmed only after macOS keyed the app's window
/// on another Space and our follow switched there; the heal runs
/// the #936 close-return as if the removal had landed when the
/// episode opened. Driven through `handle` in the issue's log
/// order — refusal, same-app focus honored, follow, confirmation.
/// Serialized: the topology override is process-global.
@Suite("Delayed close return (#2002)", .serialized)
@MainActor
struct DelayedCloseReturnTests {
    private let app: pid_t = 50
    private let other: pid_t = 60
    private let closing = WindowID(1)
    private let successor = WindowID(2)
    private let fallback = WindowID(3)

    private final class Log {
        var lines: [String] = []
        func has(_ needle: String) -> Bool {
            lines.contains { $0.contains(needle) }
        }
    }

    /// Space 1 (active) holds the closing window and another
    /// app's window; the successor, the closing window's app,
    /// sits on Space 2 — or on Space 1 when `sameSpace`.
    private func makeCore(
        sameSpace: Bool = false
    ) -> (KiwiCore, Log) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-2002-\(UUID().uuidString)")
        )
        let now = Date()
        core.wallClock = { now }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        let members: [(WindowID, pid_t, String)] = [
            (closing, app, "1"), (fallback, other, "1"),
            (successor, app, sameSpace ? "1" : "2"),
        ]
        for (id, pid, space) in members {
            core.state.windows.upsert(
                ManagedWindow(id: id, pid: pid, appName: "App\(pid)")
            )
            core.state.workspaces.add(id, to: SpaceID(space))
        }
        if !sameSpace {
            core.state.workspaces.focus(successor, in: "2")
        }
        core.state.workspaces.focus(closing, in: "1")
        let log = Log()
        core.onLog = { log.lines.append($0) }
        return (core, log)
    }

    /// The sweep's refusal: the episode the distrust opens.
    private func refuse(_ core: KiwiCore) {
        core.eventLoop.removalDistrusted[closing] = 1
    }

    /// macOS keys the successor; the deferred follow is landed by
    /// hand, its gate reading the live frontmost.
    private func keySuccessor(_ core: KiwiCore, follow: Bool = true) {
        core.handle(.windowFocused(successor))
        core.deferred.cancel(.focusFollow)
        if follow {
            core.landFocusFollow(successor, on: "2")
            #expect(core.state.workspaces.activeSpace == "2")
        }
    }

    private func confirmClose(_ core: KiwiCore) {
        core.handle(.windowDestroyed(closing, wasMinimized: false))
    }

    private func expectReturned(_ core: KiwiCore, _ log: Log) {
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.activeSpace?.focused == fallback)
        #expect(log.has("close-return: raising w\(fallback.raw)"))
    }

    private func expectUntouched(_ core: KiwiCore, _ log: Log) {
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.activeSpace?.focused == successor)
        #expect(!log.has("close-return: raising"))
        #expect(core.delayedCloseDebt == nil)
    }

    @Test("A delayed close returns to its Space's fallback")
    func delayedCloseReturns() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core)
        confirmClose(core)
        expectReturned(core, log)
        #expect(log.has("confirmed late — returning to space 1"))
        #expect(core.delayedCloseDebt == nil)
    }

    @Test("A press during the episode stands the return down")
    func pressStandsDown() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core)
        core.lastLeftClick = (core.wallClock(), .zero, nil)
        confirmClose(core)
        expectUntouched(core, log)
        #expect(log.has("return stood down (a press)"))
    }

    @Test("A commanded focus during the episode stands it down")
    func commandStandsDown() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core)
        core.eventLoop.lastCommandedFocus =
            ContinuousClock.now.advanced(by: .milliseconds(5))
        confirmClose(core)
        expectUntouched(core, log)
        #expect(log.has("return stood down (a commanded focus)"))
    }

    /// The user's own switch to the successor's Space beats the
    /// follow there, which then stands down: no follow, no debt.
    @Test("A user Space switch before the follow stands it down")
    func userSwitchStandsDown() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core, follow: false)
        core.switchSpace(to: "2", warp: false)
        confirmClose(core)
        expectUntouched(core, log)
        #expect(log.has("return stood down (no follow of the successor)"))
    }

    @Test("A confirmation past the bound stands it down")
    func expiredStandsDown() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core)
        let late = core.wallClock().addingTimeInterval(
            core.delayedCloseBound + 0.1
        )
        core.wallClock = { late }
        confirmClose(core)
        expectUntouched(core, log)
        #expect(log.has("return stood down (expired)"))
    }

    /// No episode: the app never reported the close, so the
    /// #1930 order stands — the focus moved first, nothing raises.
    @Test("An undistrusted close after the focus moved is untouched")
    func undistrustedCloseUntouched() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        keySuccessor(core)
        confirmClose(core)
        expectUntouched(core, log)
        #expect(!log.has("close distrust:"))
    }

    @Test("A successor on the closed window's own Space is untouched")
    func sameSpaceSuccessorUntouched() {
        let (core, log) = makeCore(sameSpace: true)
        defer { NativeSpaces.spacesOverride = nil }
        refuse(core)
        keySuccessor(core, follow: false)
        #expect(core.delayedCloseDebt == nil)
        confirmClose(core)
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.activeSpace?.focused == successor)
        #expect(!log.has("close-return: raising"))
        #expect(!log.has("close distrust:"))
    }

    /// The close that lands while it still holds the focus raises
    /// the fallback as it always did, with no debt involved.
    @Test("An undelayed close of the focus raises as today")
    func undelayedCloseRaises() {
        let (core, log) = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
        confirmClose(core)
        expectReturned(core, log)
        #expect(!log.has("close distrust:"))
    }
}
