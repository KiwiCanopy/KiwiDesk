import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An own raise is never a bounce (#1281): a report of a placed
/// window the focus command already INTENDED is honored, because
/// the distrust asks `intended != id`. The GUI's Settings raise
/// rides this (`SettingsOpenFocusSeamTests`); the negative
/// control — the same report with no intent — is the second
/// case here and `PlacementBounceTests`' first.
@Suite(
    "A placed window the focus command intended (#1281)",
    .serialized
)
@MainActor
struct PlacementIntentTests {
    /// A frame straddling the screen edge (bounds end at
    /// x = 1440) — the scrolling pan's ask the distrust was
    /// measured against.
    private let offscreen = CGRect(
        x: 1200,
        y: 100,
        width: 400,
        height: 300
    )

    /// Two windows on one scrolling space, `other` focused —
    /// `PlacementBounceTests`' fixture, kept small rather than
    /// shared (§2.4).
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-placement-intent-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for id in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)",
                        frame: CGRect(
                            x: 500 * CGFloat(id - 1),
                            y: 0,
                            width: 400,
                            height: 300
                        )
                    )
                )
            )
        }
        let target = WindowID(1)
        let other = WindowID(2)
        let space = core.state.workspaces.space(of: target)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.tiler.placements = PlacementLedger()
        core.state.workspaces.focus(other, in: space)
        return (core, target, other)
    }

    @Test("A clickless report of a window focusWindow intended is honored")
    func intendedReportIsHonored() {
        let (core, target, _) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        core.focusWindow(target, warp: false)
        // The command's own pan re-stamped it: the ledger is
        // LIVE when the report lands, and it is still honored.
        #expect(core.tiler.placements.recent(target) != nil)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
    }

    @Test("Without the intent the same report is bounced")
    func unintendedReportIsBounced() {
        let (core, target, other) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }
}
