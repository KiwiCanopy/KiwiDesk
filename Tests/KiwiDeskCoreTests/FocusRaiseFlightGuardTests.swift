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
        core.raiseFlight = RaiseFlight(
            target: anchor,
            leftPID: 777,
            issuedAt: core.wallClock()
        )
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

    @Test("A press after the raise refuses")
    func pressSinceRaiseRefuses() {
        let core = makeCore()
        raise(core, to: anchor)
        core.lastLeftClick = (
            core.wallClock().addingTimeInterval(0.1),
            .zero,
            nil
        )
        #expect(preflight(core, "focus")?.error == Self.generic)
        core.lastLeftClick = (
            core.wallClock().addingTimeInterval(-0.1),
            .zero,
            nil
        )
        #expect(preflight(core, "focus") == nil)
    }

    /// A click during the pan is the user's too: the press is
    /// judged against the `focus` press, not the deferred raise's
    /// later restamp.
    @Test("A click mid-pan refuses")
    func clickMidPanRefuses() {
        let core = makeCore()
        raise(core, to: anchor, age: 0.5)
        core.lastLeftClick = (
            core.wallClock().addingTimeInterval(-0.2),
            .zero,
            nil
        )
        core.pendingFocusRaise = anchor
        core.runPendingFocusRaise()
        #expect(preflight(core, "focus")?.error == Self.generic)
    }
}
