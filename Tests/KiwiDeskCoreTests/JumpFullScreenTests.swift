import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// Jump to a window on its own native full-screen Space (#2939):
/// the window is raised there through the element KiwiDesk kept at
/// its departure, or held while tracked, and its app is brought
/// forward only where no element answers. Process-global overrides,
/// so serialized.
@MainActor
@Suite("Jump to a full-screen window", .serialized)
struct JumpFullScreenTests {
    private let pid: pid_t = 900_210
    private let id = WindowID(7)

    /// Desktop 1 shown, Desktop 4 away, Space 9 a full-screen one.
    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
            authoritySpace(9, display: "UUID-A", isUser: false),
        ]
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        return core
    }

    private func window(fullscreen: Bool = false) -> ManagedWindow {
        var window = ManagedWindow(
            id: id,
            pid: pid,
            appName: "Notes",
            appBundleID: "app.test.notes"
        )
        window.isFullscreen = fullscreen
        return window
    }

    /// The sweep's order: the registration is released, then the
    /// destroy is folded, with the compositor hosting the window on
    /// `host`.
    private func depart(
        _ core: KiwiCore,
        to host: SkyLight.SpaceID,
        element: AXUIElement
    ) {
        core.eventLoop.onEvent(.windowCreated(window()))
        core.eventLoop.elements[pid] = [id: element]
        core.desktopMemory.readWindowSpace = { _ in .hosted(host) }
        core.eventLoop.releaseWindowRegistration(id, pid: pid)
        core.eventLoop.onEvent(.windowDestroyed(id, wasMinimized: false))
    }

    private struct Calls {
        var raised: [(AXUIElement, WindowID)] = []
        var activated: [pid_t] = []
    }

    private func record(
        _ core: KiwiCore,
        raises: Bool = true
    ) -> () -> Calls {
        var calls = Calls()
        core.openOrFocus.raiseFullScreen = { element, window, _ in
            calls.raised.append((element, window))
            return raises
        }
        core.openOrFocus.activate = { calls.activated.append($0) }
        return { calls }
    }

    @Test("an away full-screen window is raised by its kept element")
    func awayRaisesKeptElement() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        let element = AXUIElementCreateApplication(pid)
        depart(core, to: 9, element: element)
        #expect(core.state.awayWindows[id]?.nativeSpace == 9)
        let calls = record(core)
        core.jump(to: .window(id))
        #expect(calls().raised.map(\.1) == [id])
        #expect(calls().raised.first.map { CFEqual($0.0, element) } == true)
        #expect(calls().activated.isEmpty)
    }

    @Test("a raise the element refuses brings the app forward")
    func refusedRaiseActivates() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        depart(core, to: 9, element: AXUIElementCreateApplication(pid))
        let calls = record(core, raises: false)
        core.jump(to: .window(id))
        #expect(calls().raised.count == 1)
        #expect(calls().activated == [pid])
    }

    @Test("a departure to a user Desktop keeps no element")
    func userDesktopKeepsNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        depart(core, to: 4, element: AXUIElementCreateApplication(pid))
        #expect(core.state.awayWindows[id] != nil)
        let away = Set(core.state.awayWindows.keys)
        #expect(
            core.eventLoop.fullScreenElements.element(of: id, away: away)
                == nil
        )
    }

    @Test("a window the ledger no longer lists drops its element")
    func ledgerEndDropsElement() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        depart(core, to: 9, element: AXUIElementCreateApplication(pid))
        let kept = Set(core.state.awayWindows.keys)
        #expect(
            core.eventLoop.fullScreenElements.element(of: id, away: kept)
                != nil
        )
        #expect(
            core.eventLoop.fullScreenElements.element(of: id, away: [])
                == nil
        )
        #expect(
            core.eventLoop.fullScreenElements.element(of: id, away: kept)
                == nil
        )
    }

    /// Full screen since before KiwiDesk adopted it: the residue.
    @Test("a full-screen window with no element brings its app forward")
    func noElementActivates() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.awayWindows[id] = AwayWindow(
            id: id,
            pid: pid,
            appName: "Notes",
            appBundleID: "app.test.notes",
            nativeSpace: 9
        )
        let calls = record(core)
        core.jump(to: .window(id))
        #expect(calls().raised.isEmpty)
        #expect(calls().activated == [pid])
    }

    @Test("a tracked full-screen window is raised by its own element")
    func trackedRaises() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.apply(.windowCreated(window(fullscreen: true)))
        core.state.workspaces.add(id, to: "1")
        let element = AXUIElementCreateApplication(pid)
        core.eventLoop.elements[pid] = [id: element]
        let calls = record(core)
        core.jump(to: .window(id))
        #expect(calls().raised.map(\.1) == [id])
        #expect(calls().activated.isEmpty)
        #expect(core.selfRaiseStamp(id, now: core.wallClock()) != nil)
    }
}
