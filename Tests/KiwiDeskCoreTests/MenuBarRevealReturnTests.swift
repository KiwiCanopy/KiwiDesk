import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1532 menu-bar reveal return: with the bar auto-hidden,
/// macOS 27 answers the pointer reaching the top edge by
/// activating the last regular app — KiwiDesk is an accessory
/// app — and a clickless foreign focus report lands ~190 ms
/// later. The return keeps state focus on the own window; each
/// let-out (a press, the one-shot bound, a foreign anchor, a
/// self echo, the pointer elsewhere) is a case below. The device
/// evidence is on the issue.
@Suite("Menu-bar reveal return (#1532)", .serialized)
@MainActor
struct MenuBarRevealReturnTests {
    /// The return's log phrase, asserted POSITIVELY on a return
    /// and NEGATIVELY on the silent let-outs — one constant, so
    /// a reword of the production line reds the positive half
    /// instead of leaving the negative one vacuously green.
    private static let returnLogNeedle = "menu-bar reveal activation"

    /// Windows 1 (OUR pid — the anchor) and 2 (a foreign regular
    /// app), window 1 focused, the pointer read pinned IN the
    /// strip: the reveal's shape.
    private func makeCore(inStrip: Bool = true) -> KiwiCore {
        let core = makeTestCore()
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: own,
                    appName: "KiwiDesk"
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 99,
                    appName: "Other"
                )
            )
        )
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.mouse.pointerInMenuBarStrip = { inStrip }
        return core
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.state.workspaces[SpaceID(1)]?.focused
    }

    @Test("The reveal's activation is returned to the own window")
    func activationIsReturned() {
        let core = makeCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        #expect(log.contains { $0.contains(Self.returnLogNeedle) })
        #expect(core.menuBarRevealReturnAt != nil)
    }

    @Test("The pointer elsewhere makes it an ordinary focus")
    func pointerAwayIsHonored() {
        let core = makeCore(inStrip: false)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
    }

    @Test("A left press anywhere is the user choosing")
    func recentPressStandsDown() {
        // A click into the revealed bar's menus reaches no
        // managed window, so the stand-down is ANY press, not a
        // press that reached the reported window.
        let core = makeCore()
        core.lastLeftClick = (at: Date(), point: .zero, reached: nil)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
    }

    @Test("One return per reveal; the bound then re-opens")
    func oneReturnInsideTheWindow() {
        let core = makeCore()
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        // A second activation inside the bound is honored — an
        // activation KiwiDesk could not hold is never fought
        // twice.
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        // Past the bound, the next reveal is returned again.
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.menuBarRevealReturnAt = Date(
            timeIntervalSinceNow:
                -KiwiCore.menuBarRevealReturnWindow - 1
        )
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
    }

    @Test("A foreign anchor is never returned to")
    func foreignAnchorIsHonored() {
        // Only an accessory app's window is skipped by the
        // activation; a regular app's focused window is where
        // macOS lands anyway, so there is nothing to return.
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(3),
                    pid: 77,
                    appName: "Third"
                )
            )
        )
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(3)))
        #expect(focused(core) == WindowID(3))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
    }

    @Test("A report for an own window is never returned")
    func ownReportIsNotReturned() {
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(4),
                    pid: pid_t(ProcessInfo.processInfo.processIdentifier),
                    appName: "KiwiDesk"
                )
            )
        )
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(4)))
        #expect(focused(core) == WindowID(4))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
    }

    @Test("Our own raise's echo is not a reveal")
    func selfEchoIsNotReturned() {
        let core = makeCore()
        core.selfRaiseStamps[WindowID(2)] = Date()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
        #expect(core.menuBarRevealReturnAt == nil)
    }

    // MARK: the strip geometry

    @Test("The band is the deeper of the safe area and the bar")
    func bandTakesTheDeeper() {
        #expect(MenuBarReveal.band(safeTop: 37, barHeight: 24) == 37)
        #expect(MenuBarReveal.band(safeTop: 0, barHeight: 24) == 24)
    }

    @Test("The strip is the top band of the pointer's screen")
    func stripIsTheTopBand() {
        let main = MenuBarReveal.Screen(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            band: 37
        )
        let right = MenuBarReveal.Screen(
            frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
            band: 24
        )
        let screens = [main, right]
        // Resting ON the edge reads y == maxY: inside.
        #expect(
            MenuBarReveal.pointerInStrip(
                CGPoint(x: 864, y: 1117),
                screens: screens
            )
        )
        #expect(
            MenuBarReveal.pointerInStrip(
                CGPoint(x: 864, y: 1081),
                screens: screens
            )
        )
        #expect(
            !MenuBarReveal.pointerInStrip(
                CGPoint(x: 864, y: 1079),
                screens: screens
            )
        )
        // The other screen's own band, not the main one's.
        #expect(
            MenuBarReveal.pointerInStrip(
                CGPoint(x: 3000, y: 1420),
                screens: screens
            )
        )
        #expect(
            !MenuBarReveal.pointerInStrip(
                CGPoint(x: 3000, y: 1400),
                screens: screens
            )
        )
        // Off every screen: nowhere to reveal.
        #expect(
            !MenuBarReveal.pointerInStrip(
                CGPoint(x: 5000, y: 10),
                screens: screens
            )
        )
    }
}
