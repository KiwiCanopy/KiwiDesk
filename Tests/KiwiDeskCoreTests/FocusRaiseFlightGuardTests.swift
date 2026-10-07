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

    @Test("A fresh self-raise of the anchor lets focus through")
    func freshRaiseAllowsFocus() {
        let core = makeCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.stampSelfRaise(anchor, now: core.wallClock())
        #expect(preflight(core, "focus") == nil)
        #expect(logs.contains { $0.contains("own raise") })
    }

    @Test("A raise deferred behind a pan lets focus through")
    func pendingRaiseAllowsFocus() {
        let core = makeCore()
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
        core.stampSelfRaise(previous, now: core.wallClock())
        core.pendingFocusRaise = previous
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("A stale raise is refused")
    func staleRaiseRefuses() {
        let core = makeCore()
        let past = core.wallClock().addingTimeInterval(
            -KiwiCore.selfRaiseEchoWindow
        )
        core.stampSelfRaise(anchor, now: past)
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("Every other focused verb stays refused")
    func otherVerbsRefuse() {
        let core = makeCore()
        core.stampSelfRaise(anchor, now: core.wallClock())
        core.pendingFocusRaise = anchor
        for verb in FocusedCommandPolicy.focusedCommands
        where verb != "focus" {
            #expect(
                core.focusedCommandDenial(for: verb, []) != nil,
                "\(verb) passed the preflight"
            )
        }
    }

    @Test("An unmanaged app in front is #292's refusal")
    func unmanagedFrontRefuses() {
        let core = makeCore()
        core.stampSelfRaise(anchor, now: core.wallClock())
        core.frontmostPIDProvider = { 777 }
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("An ignored panel latched on the anchor refuses")
    func latchedPanelRefuses() {
        let core = makeCore()
        core.stampSelfRaise(anchor, now: core.wallClock())
        core.ignoredPanel.active.insert(getpid())
        #expect(preflight(core, "focus")?.error == Self.generic)
    }

    @Test("The bypass rides the real dispatch")
    func executeHonorsTheBypass() {
        let core = makeCore()
        core.stampSelfRaise(anchor, now: core.wallClock())
        let response = core.execute("focus", args: [.string("left")])
        #expect(response.error != Self.generic)
    }
}
