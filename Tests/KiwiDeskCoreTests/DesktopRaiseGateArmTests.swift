import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The three distrust re-asserts under the Desktop raise gate
/// (#1345): the placement bounce (#1161), the sibling re-report
/// (#465) and the accessibility-steal return (#958) each re-assert
/// an intended window with a direct raise. When that window is
/// hosted on a Desktop nobody shows — the Desktop the user just
/// left, still in state behind a slow app's destroy — the arm
/// stands down and the report is honored. Each arm's own fixture
/// is copied from its suite; the shown control beside each case
/// keeps the arm itself live.
@Suite("Desktop raise gate: the re-assert arms (#1345)")
@MainActor
struct DesktopRaiseGateArmTests {
    private static let standDownNeedle = "#1345"

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-raise-gate-arms-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        return core
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        pid: pid_t
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: pid,
                    appName: "App\(pid)",
                    frame: CGRect(
                        x: 500 * CGFloat(raw - 1),
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
    }

    /// `unshown` reads as not drawn by the compositor, every
    /// other window as on screen; the focus memory's host read
    /// answers the shown Desktop for all of them.
    private func host(_ core: KiwiCore, unshown: WindowID?) {
        core.windowIsOnScreen = { $0 != unshown }
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
    }

    // MARK: - Placement bounce (#1161)

    /// `PlacementBounceTests`' fixture: two windows in a scrolling
    /// row, `other` focused, `target` placed by KiwiDesk.
    private func placementFixture(
        _ core: KiwiCore
    ) -> (target: WindowID, other: WindowID) {
        addWindow(core, 1, pid: 1)
        addWindow(core, 2, pid: 2)
        let target = WindowID(1)
        let other = WindowID(2)
        let space = core.state.workspaces.space(of: target)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.tiler.placements = PlacementLedger()
        core.state.workspaces.focus(other, in: space)
        core.tiler.placements.stamp(
            target,
            target: CGRect(x: 800, y: 100, width: 400, height: 300)
        )
        return (target, other)
    }

    @Test("A placement bounce whose re-assert crosses Desktops is honored")
    func placementBounceHonoredAcrossDesktops() {
        let core = makeCore()
        let (target, other) = placementFixture(core)
        host(core, unshown: other)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
        #expect(log.contains { $0.contains(Self.standDownNeedle) })
        #expect(
            !log.contains {
                $0.contains("placement bounce distrusted")
            }
        )
    }

    @Test("A placement bounce with a shown intended window is distrusted")
    func placementBounceDistrustedWhenShown() {
        let core = makeCore()
        let (target, other) = placementFixture(core)
        host(core, unshown: nil)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }

    /// macOS restores the Desktop's last focused window on a
    /// return, a clickless report for a window the arrival retile
    /// just placed — the bounce's shape. The #1207 memory names
    /// that window and the return is fresh, so the arm stands
    /// down on it.
    @Test("A fresh return's remembered focus is honored")
    func restoredFocusHonored() {
        let core = makeCore()
        let (target, _) = placementFixture(core)
        host(core, unshown: nil)
        let space = core.state.workspaces.space(of: target)!
        core.desktopMemory.honoredFocus[space] = [10: target]
        core.recentReturns[target] = Date()
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
    }

    @Test("A remembered focus of another window is still distrusted")
    func otherRememberedFocusStillDistrusted() {
        let core = makeCore()
        let (target, other) = placementFixture(core)
        host(core, unshown: nil)
        let space = core.state.workspaces.space(of: target)!
        core.desktopMemory.honoredFocus[space] = [10: other]
        core.recentReturns[target] = Date()
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }

    /// Bound to the RETURN: the same memory entry past the
    /// restore window is the steady state, where the memory names
    /// whatever was honored last and an app's bounce keeps its
    /// distrust.
    @Test("A remembered focus without a fresh return is still distrusted")
    func staleReturnStillDistrusted() {
        let core = makeCore()
        let (target, other) = placementFixture(core)
        host(core, unshown: nil)
        let space = core.state.workspaces.space(of: target)!
        core.desktopMemory.honoredFocus[space] = [10: target]
        core.recentReturns[target] = Date(
            timeIntervalSinceNow: -KiwiCore.restoredFocusWindow - 1
        )
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }

    /// The production writer of `recentReturns`: an arrival the
    /// fold classifies `.returned` (a remembered Space) stamps it,
    /// so the report that follows is honored; a `.new` arrival
    /// stamps nothing and its report keeps the distrust.
    @Test("A returned arrival stamps the return; a new one does not")
    func returnedArrivalStampsTheReturn() {
        let core = makeCore()
        addWindow(core, 2, pid: 2)
        let target = WindowID(1)
        let other = WindowID(2)
        let space = core.state.workspaces.space(of: other)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        host(core, unshown: nil)
        core.desktopMemory.honoredFocus[space] = [10: target]
        // The return: remembered in the space, then re-created.
        core.state.remember(target, in: space)
        core.handle(
            .windowCreated(
                ManagedWindow(id: target, pid: 1, appName: "App1")
            )
        )
        #expect(core.recentReturns[target] != nil)
        core.state.workspaces.focus(other, in: space)
        core.tiler.placements = PlacementLedger()
        core.tiler.placements.stamp(
            target,
            target: CGRect(x: 800, y: 100, width: 400, height: 300)
        )
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
    }

    @Test("A new arrival stamps no return")
    func newArrivalStampsNothing() {
        let core = makeCore()
        core.handle(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 1, appName: "App1")
            )
        )
        #expect(core.recentReturns[WindowID(1)] == nil)
    }

    /// Both #1345 ledgers are id-keyed and ride the native-tab
    /// re-key (#308) with the rest.
    @Test("A re-key carries the return stamp and the departure record")
    func rekeyCarriesBothLedgers() {
        let core = makeCore()
        addWindow(core, 1, pid: 1)
        let old = WindowID(1)
        let new = WindowID(9)
        let stamp = Date()
        core.recentReturns[old] = stamp
        core.desktopMoveDepartures[old] = stamp
        core.handle(.windowRekeyed(old, new))
        #expect(core.recentReturns[old] == nil)
        #expect(core.recentReturns[new] == stamp)
        #expect(core.desktopMoveDepartures[old] == nil)
        #expect(core.desktopMoveDepartures[new] == stamp)
    }

    // MARK: - Sibling re-report (#465)

    /// `ActivationReReportTests`' fixture: window 1 (pid 5) hidden
    /// on space 2, window 2 (pid 5) the active space's focus and
    /// the freshly raised sibling.
    private func siblingFixture(_ core: KiwiCore) {
        addWindow(core, 1, pid: 5)
        addWindow(core, 2, pid: 5)
        core.moveWindow(WindowID(1), to: SpaceID(2), follow: false)
        core.moveLatch.stamp(
            WindowID(1),
            at: Date(
                timeIntervalSinceNow:
                    -MoveIntentLatch.window - 1
            )
        )
        core.selfRaiseStamps[WindowID(2)] = Date()
    }

    @Test("A sibling re-report whose re-assert crosses Desktops is honored")
    func siblingReportHonoredAcrossDesktops() {
        let core = makeCore()
        siblingFixture(core)
        host(core, unshown: WindowID(2))
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("A sibling re-report with a shown intended window is distrusted")
    func siblingReportDistrustedWhenShown() {
        let core = makeCore()
        siblingFixture(core)
        host(core, unshown: nil)
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    // MARK: - Accessibility-steal return (#958)

    private static let voBundle = "com.apple.universalaccesscontrol"
    private static let returnNeedle = "accessibility-steal yield"

    /// `AccessibilityReturnTests`' fixture: window 1 is OUR pid
    /// (the victim), window 2 a foreign regular app.
    private func accessibilityFixture(_ core: KiwiCore) {
        let own = pid_t(ProcessInfo.processInfo.processIdentifier)
        addWindow(core, 1, pid: own)
        addWindow(core, 2, pid: 99)
        core.state.workspaces.focus(WindowID(1), in: SpaceID(1))
        core.eventLoop.onIgnoredPanelFocus(7, Self.voBundle)
    }

    @Test("A yield whose return crosses Desktops is honored, the debt spent")
    func yieldHonoredAcrossDesktops() {
        let core = makeCore()
        accessibilityFixture(core)
        #expect(core.accessibilityReturn != nil)
        host(core, unshown: WindowID(1))
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused == WindowID(2)
        )
        #expect(!log.contains { $0.contains(Self.returnNeedle) })
        #expect(log.contains { $0.contains(Self.standDownNeedle) })
        #expect(core.accessibilityReturn == nil)
    }

    @Test("A yield with a shown victim is still returned")
    func yieldReturnedWhenShown() {
        let core = makeCore()
        accessibilityFixture(core)
        host(core, unshown: nil)
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused == WindowID(1)
        )
    }
}
