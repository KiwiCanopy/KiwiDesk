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
        // Stamped AHEAD: an "inside the window" verdict measured
        // against the wall clock races a starved runner (#1371).
        core.lastLeftClick = (
            at: Date(timeIntervalSinceNow: 60),
            point: .zero,
            reached: nil
        )
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
        // twice. The stamp is set AHEAD so the verdict does not
        // ride how long the runner took between the two calls.
        core.menuBarRevealReturnAt = Date(timeIntervalSinceNow: 60)
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

    /// The reason the re-assert is a stamped raise and not the
    /// focus command: the command's displacement note would put
    /// the foreign window in the placement ledger, and in an
    /// ACTIVE scrolling Space that live entry is the whole #1161
    /// verdict — every later report from that app bounced for the
    /// ledger's window, so the one-shot never decided there.
    @Test("In scrolling the one-shot still decides the second report")
    func scrollingHonorsTheSecondReport() {
        let core = makeCore()
        core.state.workspaces.setMode(SpaceID(1), .scrolling)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(1))
        #expect(core.tiler.placements.recent(WindowID(2)) == nil)
        core.menuBarRevealReturnAt = Date(timeIntervalSinceNow: 60)
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
    }

    /// The #1345 stand-down, beside a shown control: a return
    /// that would switch Desktops is refused and the report
    /// honored, the arm neither returning nor stranding state.
    @Test("A return that crosses Desktops is honored instead")
    func crossingReturnIsHonored() {
        let core = makeCore()
        core.windowIsOnScreen = { $0 != WindowID(1) }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(focused(core) == WindowID(2))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
        #expect(log.contains { $0.contains("#1345") })
        #expect(core.menuBarRevealReturnAt == nil)
        // The control: shown, the same report is returned.
        let shown = makeCore()
        shown.windowIsOnScreen = { _ in true }
        shown.desktopMemory.readWindowSpace = { _ in .hosted(10) }
        shown.handle(.windowFocused(WindowID(2)))
        #expect(focused(shown) == WindowID(1))
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
        // The create fold focused the newcomer; anchor window 1
        // again so only the pid clause stands between this report
        // and a return (guard-prover, 2026-09-21).
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(4)))
        #expect(focused(core) == WindowID(4))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
    }

    @Test("Our own raise's echo is not a reveal")
    func selfEchoIsNotReturned() {
        let core = makeCore()
        core.selfRaiseStamps[WindowID(2)] = Date(
            timeIntervalSinceNow: 60
        )
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(!log.contains { $0.contains(Self.returnLogNeedle) })
        #expect(core.menuBarRevealReturnAt == nil)
    }

    // MARK: the strip geometry

    @Test("The band is the deepest of the three readings")
    func bandTakesTheDeepest() {
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 37,
                reservedTop: 32,
                barHeight: 24
            ) == 37
        )
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 0,
                reservedTop: 0,
                barHeight: 24
            ) == 24
        )
        // The bare-menu reading (0) never collapses the band.
        #expect(
            GeometryUtils.menuBarBand(
                safeTop: 0,
                reservedTop: 24,
                barHeight: 0
            ) == 24
        )
    }

    @Test("The strip is the top band of the pointer's screen")
    func stripIsTheTopBand() {
        let main = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
            band: 37
        )
        let right = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440),
            band: 24
        )
        let screens = [main, right]
        // Resting ON the edge reads y == maxY: inside.
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1117),
                screens: screens
            )
        )
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1081),
                screens: screens
            )
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 864, y: 1079),
                screens: screens
            )
        )
        // The other screen's own band, not the main one's.
        #expect(
            GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 3000, y: 1420),
                screens: screens
            )
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 3000, y: 1400),
                screens: screens
            )
        )
        // A point on the seam between stacked screens is the
        // upper one's bottom row, not the lower one's strip.
        let lower = GeometryUtils.MenuBarScreen(
            frame: CGRect(x: 0, y: -1000, width: 1728, height: 1000),
            band: 24
        )
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 100, y: 0),
                screens: [lower, main]
            )
        )
        // Off every screen: nowhere to reveal.
        #expect(
            !GeometryUtils.pointerInMenuBarStrip(
                CGPoint(x: 5000, y: 10),
                screens: screens
            )
        )
    }
}
