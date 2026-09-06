import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The one press stamp (#1281): `stampLeftClick` resolves the
/// window a press reached at press time, and that provenance
/// beats the #1161 placement bounce (#687's escape). Both press
/// arms take it; `OwnPressProvenanceSeamTests` holds the wiring
/// and the argument is in `docs/design-decisions.md`.
@Suite("Own-window click provenance (#1281)", .serialized)
@MainActor
struct OwnPressProvenanceTests {
    private let offscreen = CGRect(
        x: 1200,
        y: 100,
        width: 400,
        height: 300
    )

    /// Two windows on one scrolling space, `other` focused, the
    /// stacking seam wired so a press resolves — the
    /// `PlacementBounceTests` fixture plus the provider.
    private func makeFixture() -> (
        core: KiwiCore, target: WindowID, other: WindowID
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-own-press-\(UUID().uuidString)"
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
        core.stackingOrderProvider = { [target, other] }
        return (core, target, other)
    }

    @Test("The stamp resolves the window the press reached")
    func stampResolvesTheWindow() {
        let (core, target, other) = makeFixture()
        let inside = core.state.windows[target]!.frame
        core.stampLeftClick(
            at: CGPoint(x: inside.midX, y: inside.midY)
        )
        #expect(core.recentClickReached(target, now: Date()))
        #expect(!core.recentClickReached(other, now: Date()))
    }

    @Test("A press outside every window carries no provenance")
    func stampOutsideReachesNothing() {
        let (core, target, other) = makeFixture()
        core.stampLeftClick(at: CGPoint(x: 1400, y: 800))
        #expect(!core.recentClickReached(target, now: Date()))
        #expect(!core.recentClickReached(other, now: Date()))
    }

    @Test("A stamped press beats the placement bounce")
    func stampedPressEscapesTheBounce() {
        let (core, target, _) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        let inside = core.state.windows[target]!.frame
        core.stampLeftClick(
            at: CGPoint(x: inside.midX, y: inside.midY)
        )
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == target)
    }

    @Test("Without the stamp the same report is bounced")
    func unstampedReportIsBounced() {
        let (core, target, other) = makeFixture()
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(core.activeSpace?.focused == other)
    }
}
