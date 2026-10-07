import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Where a raise flight (#1812) is written, carried and ended:
/// the `focus` verb records it — a Monocle flip's owed target
/// included — a re-assert never does, a deferred raise or a
/// landing flip restamps it, a tab switch rekeys it, and any app
/// activation ends it. `FocusRaiseFlightGuardTests` reads it.
@Suite("Raise flight write sites", .serialized)
@MainActor
struct FocusRaiseFlightRecordTests {
    private static let generic = "no managed window is currently focused"
    private let anchor = WindowID(1)
    private let previous = WindowID(2)
    private let previousPID: pid_t = 999

    /// The previous app's window, then the anchor — created last,
    /// so it holds the focus — owned by this process, whose
    /// observer is real so `observes(pid:)` answers.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-flight-\(UUID().uuidString)"
                )
        )
        let own = getpid()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: previous,
                    pid: previousPID,
                    appName: "Previous"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: anchor, pid: own, appName: "Anchor")
            )
        )
        #expect(core.focusedWindow?.id == anchor)
        guard let observer = AXApplicationObserver(pid: own) else {
            Issue.record("could not create a self AX observer")
            return core
        }
        core.eventLoop.observers[own] = observer
        core.frontmostPIDProvider = { [previousPID] in previousPID }
        return core
    }

    private func preflight(
        _ core: KiwiCore,
        _ command: String
    ) -> CommandResponse? {
        core.focusedCommandDenial(for: command, [.string("left")])
    }

    /// A `focus` press's raise toward `id`, issued with the
    /// previous app in front, `age` seconds ago on the core's
    /// frozen clock.
    private func raise(
        _ core: KiwiCore,
        to id: WindowID,
        age: TimeInterval = 0
    ) {
        core.raiseFlight = RaiseFlight(
            target: id,
            leftPID: previousPID,
            issuedAt: core.wallClock().addingTimeInterval(-age)
        )
    }

    /// A long pan must not spend the flight before the raise is
    /// sent: the deferred raise restamps it as it fires.
    @Test("The deferred raise restamps the flight")
    func deferredRaiseRestamps() {
        let core = makeCore()
        raise(core, to: anchor, age: KiwiCore.selfRaiseEchoWindow)
        core.pendingFocusRaise = anchor
        core.runPendingFocusRaise()
        #expect(core.pendingFocusRaise == nil)
        #expect(preflight(core, "focus") == nil)
    }

    @Test("A native tab switch carries the flight")
    func rekeyCarriesTheFlight() {
        let core = makeCore()
        raise(core, to: anchor)
        core.handleWindowRekeyed(old: anchor, new: WindowID(9))
        #expect(core.raiseFlight?.target == WindowID(9))
    }

    /// The raise landed and the user went back to the app it
    /// left: that activation ends the flight, so the press is
    /// #292's refusal again.
    @Test("An app activation ends the flight")
    func activationEndsTheFlight() {
        let core = makeCore()
        raise(core, to: anchor)
        core.eventLoop.onAppActivated(
            AppActivation(
                pid: previousPID,
                bundleID: nil,
                launchedAt: nil
            )
        )
        #expect(core.raiseFlight == nil)
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    /// The write site: a `focus` press that moved the anchor
    /// records its raise and the app in front as it ran.
    @Test("The focus verb records the flight it starts")
    func focusVerbRecords() {
        let core = makeCore()
        guard let space = core.state.workspaces.space(of: anchor)
        else {
            Issue.record("no space")
            return
        }
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        core.frontmostPIDProvider = { getpid() }
        #expect(
            core.execute("focus", args: [.string("left")]).isSuccess
        )
        #expect(core.focusedWindow?.id == previous)
        #expect(core.raiseFlight?.target == previous)
        #expect(core.raiseFlight?.leftPID == getpid())
    }

    /// A `focusWindow` re-assert after the user switched apps —
    /// the z-order restore's closing one — records nothing, so
    /// the app switched to never reads as the one left.
    @Test("A re-assert after a switch records no flight")
    func reassertRecordsNothing() {
        let core = makeCore()
        raise(core, to: anchor)
        let other: pid_t = 555
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: other, appName: "T")
            )
        )
        if let home = core.state.workspaces.space(of: anchor) {
            core.state.workspaces.focus(anchor, in: home)
        }
        core.frontmostPIDProvider = { other }
        core.eventLoop.onAppActivated(
            AppActivation(pid: other, bundleID: nil, launchedAt: nil)
        )
        core.focusWindow(anchor, warp: false)
        #expect(core.raiseFlight == nil)
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    /// A Monocle flip defers the state write (#1391): the press
    /// records the focus the flip owes, not the unmoved anchor.
    @Test("A flip's owed focus is the flight's target")
    func flipOwedTargetRecords() {
        let core = makeCore()
        core.pendingMonocleFocus = (from: anchor, to: previous, warp: false)
        _ = core.focusRecordingFlight([.string("nowhere")])
        #expect(core.raiseFlight?.target == previous)
        #expect(core.raiseFlight?.leftPID == previousPID)
    }

    @Test("A landing flip restamps the flight")
    func flipLandingRestamps() {
        let core = makeCore()
        raise(core, to: anchor, age: KiwiCore.selfRaiseEchoWindow)
        core.pendingMonocleFocus = (from: previous, to: anchor, warp: false)
        core.runPendingMonocleFocus()
        #expect(preflight(core, "focus") == nil)
    }
}
