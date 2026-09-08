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
/// keeps the arm itself live. Serialized: the topology override is
/// process-global.
@Suite("Desktop raise gate: the re-assert arms (#1345)", .serialized)
@MainActor
struct DesktopRaiseGateArmTests {
    private static let standDownNeedle = "#1345"

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
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

    /// `unshown` reads as hosted on the Desktop nobody shows,
    /// every other window on the shown one.
    private func host(_ core: KiwiCore, unshown: WindowID?) {
        core.desktopMemory.readWindowSpace = {
            $0 == unshown ? .hosted(11) : .hosted(10)
        }
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
        defer { NativeSpaces.spacesOverride = nil }
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
        defer { NativeSpaces.spacesOverride = nil }
        let (target, other) = placementFixture(core)
        host(core, unshown: nil)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
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
        defer { NativeSpaces.spacesOverride = nil }
        siblingFixture(core)
        host(core, unshown: WindowID(2))
        core.handle(.windowFocused(WindowID(1)))
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("A sibling re-report with a shown intended window is distrusted")
    func siblingReportDistrustedWhenShown() {
        let core = makeCore()
        defer { NativeSpaces.spacesOverride = nil }
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
        defer { NativeSpaces.spacesOverride = nil }
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
        defer { NativeSpaces.spacesOverride = nil }
        accessibilityFixture(core)
        host(core, unshown: nil)
        core.handle(.windowFocused(WindowID(2)))
        #expect(
            core.state.workspaces[SpaceID(1)]?.focused == WindowID(1)
        )
    }
}
