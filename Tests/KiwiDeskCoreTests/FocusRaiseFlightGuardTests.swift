import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #292 preflight's one bypass (#1812): `focus` runs while
/// KiwiDesk's own raise toward the anchor is in flight and the
/// frontmost app is still the managed app it left. Every other
/// verb, a stale raise and an unmanaged front stay refused.
@Suite("Focus through our own raise in flight", .serialized)
@MainActor
struct FocusRaiseFlightGuardTests {
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

    /// Our raise toward `id`, issued with the previous app in
    /// front, `age` seconds ago on the core's frozen clock.
    private func raise(
        _ core: KiwiCore,
        to id: WindowID,
        age: TimeInterval = 0
    ) {
        core.noteRaiseFlight(to: id)
        core.raiseFlight?.raisedAt = core.wallClock()
            .addingTimeInterval(-age)
    }

    @Test("A fresh raise toward the anchor lets focus through")
    func freshRaiseAllowsFocus() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        raise(core, to: anchor)
        #expect(preflight(core, "focus") == nil)
        #expect(logs.contains { $0.contains("own raise") })
    }

    @Test("A raise deferred behind a pan lets focus through")
    func pendingRaiseAllowsFocus() {
        let core = makeCore()
        raise(core, to: anchor, age: 10)
        core.pendingFocusRaise = anchor
        #expect(preflight(core, "focus") == nil)
    }

    @Test("No raise in flight: focus is refused")
    func noRaiseRefuses() {
        let core = makeCore()
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("A raise of another window does not count")
    func otherWindowsRaiseRefuses() {
        let core = makeCore()
        raise(core, to: previous)
        core.pendingFocusRaise = previous
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("A stale raise is refused")
    func staleRaiseRefuses() {
        let core = makeCore()
        raise(core, to: anchor, age: KiwiCore.selfRaiseEchoWindow)
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("Every other focused verb stays refused")
    func otherVerbsRefuse() {
        let core = makeCore()
        raise(core, to: anchor)
        core.pendingFocusRaise = anchor
        let refused = FocusedCommandPolicy.focusedCommands
            .subtracting(FocusedCommandPolicy.raiseFlightExempt)
        #expect(refused.count > 1)
        for verb in refused {
            #expect(
                core.focusedCommandDenial(for: verb, []) != nil,
                "\(verb) passed the preflight"
            )
        }
    }

    /// The user switched to another managed app after our raise:
    /// a fresh raise must not override their choice.
    @Test("Another managed app in front is #292's refusal")
    func switchedAppRefuses() {
        let core = makeCore()
        raise(core, to: anchor)
        let third: pid_t = 555
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(3), pid: third, appName: "T")
            )
        )
        let home = core.state.workspaces.space(of: anchor)
        if let home { core.state.workspaces.focus(anchor, in: home) }
        #expect(core.focusedWindow?.id == anchor)
        core.frontmostPIDProvider = { third }
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("A raise that left an unmanaged app is refused")
    func unmanagedLeftAppRefuses() {
        let core = makeCore()
        core.frontmostPIDProvider = { 777 }
        raise(core, to: anchor)
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("An ignored panel latched on either app refuses")
    func latchedPanelRefuses() {
        for pid in [getpid(), previousPID] {
            let core = makeCore()
            raise(core, to: anchor)
            core.ignoredPanel.active.insert(pid)
            #expect(
                preflight(core, "focus")?.error == Self.generic,
                "panel on \(pid)"
            )
        }
    }

    @Test("An unobserved anchor app refuses")
    func unobservedAnchorRefuses() {
        let core = makeCore()
        raise(core, to: anchor)
        core.eventLoop.observers[getpid()] = nil
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("The bypass rides the real dispatch")
    func executeHonorsTheBypass() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        raise(core, to: anchor)
        let response = core.execute("focus", args: [.string("left")])
        #expect(response.error != Self.generic)
        #expect(logs.contains { $0.contains("allowed focus") })
    }

    /// The write site: a focus command records its raise and
    /// the app in front, and the deferred raise restamps it.
    @Test("focusWindow records the flight it starts")
    func focusWindowRecords() {
        let core = makeCore()
        core.focusWindow(previous, warp: false)
        #expect(core.raiseFlight?.target == previous)
        #expect(core.raiseFlight?.leftPID == previousPID)
    }

    @Test("A re-assert of the target keeps the app it left")
    func reassertKeepsLeftApp() {
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
        core.focusWindow(anchor, warp: false)
        #expect(core.raiseFlight?.leftPID == previousPID)
        #expect(preflight(core, "focus")?.error == Self.generic)
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

    /// The wake heal (#1130) is asked before the bypass, so an
    /// armed heal is spent on the press the bypass would pass.
    @Test("The wake heal is asked before the bypass")
    func wakeHealComesFirst() {
        let core = makeCore()
        raise(core, to: anchor)
        core.trustedFrontmostProvider = { [previous] in previous }
        core.wakeFocusHealArmedAt = Date()
        _ = preflight(core, "focus")
        #expect(core.wakeFocusHealArmedAt == nil)
    }
}
