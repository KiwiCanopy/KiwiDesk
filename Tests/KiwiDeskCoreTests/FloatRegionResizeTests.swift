import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float REGION's consumers at `KiwiCore` altitude (#1091):
/// the ring inset and the `resize` verb bounded by the region. The
/// pure geometry beneath them is `FloatClampTests` and
/// `FloatSymmetricResizeTests`. No sweep fits a float into the
/// region (#3163, `FloatNeverResizedTests`).
@MainActor
@Suite("Float region resize (#1091)")
struct FloatRegionResizeTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1600,
        height: 1000
    )

    private func makeFloatCore(
        frame: CGRect
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-floatregion-\(UUID().uuidString)"
                )
        )
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "FloatApp",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        let space = core.state.workspaces.space(
            of: WindowID(1)
        )!
        core.state.workspaces.focus(WindowID(1), in: space)
        return core
    }

    @Test(
        "The ring inset follows the border setting",
        .enabled(if: NSScreen.main != nil)
    )
    func ringInsetFollowsTheSetting() {
        // The third of the three sites the ring inset runs
        // through, and the one the geometry tests cannot see:
        // `FloatClampTests` passes an inset by hand, so making
        // this read return zero left them green while every
        // float went back to sitting flush under its bar
        // (guard-prover, 2026-08-29).
        let core = makeFloatCore(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        core.tiler.settings.borderStyle.enabled = true
        core.tiler.settings.borderStyle.width = 7
        #expect(core.floatRingInset == 7)
        // Rings off means no inset at all — a float should not
        // be held clear of a bar for a ring nobody draws.
        core.tiler.settings.borderStyle.enabled = false
        #expect(core.floatRingInset == 0)
    }

    @Test(
        "A blocked grow reaches the cue funnel",
        .enabled(if: NSScreen.main != nil)
    )
    func blockedGrowCues() {
        // Both review lanes: deleting the `refuseGrowAtBoundary`
        // call left the whole suite green, because the pure flag
        // is asserted in `FloatSymmetricResizeTests` and nothing
        // read the command's use of it. That restores "the one
        // resize wall with no wall", which is the obligation the
        // rule bullet states.
        //
        // Captured at `borders.onResizeRefusal` — the one seam
        // `cueResizeRefusal` funnels through, which is also what
        // ends a held glide, so this pins the whole chain.
        let core = makeFloatCore(frame: Self.bounds)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(refusals.count == 1)
        // And a grow with room does NOT cue.
        let roomy = makeFloatCore(
            frame: CGRect(x: 200, y: 200, width: 400, height: 300)
        )
        var quiet: [ResizeRefusal] = []
        roomy.borders.onResizeRefusal = { quiet.append($0) }
        roomy.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(quiet.isEmpty)
    }

    @Test(
        "The resize measures against the region, not unbounded",
        .enabled(if: NSScreen.main != nil)
    )
    func theResizeConsultsTheRegion() {
        // The third unguarded wiring: passing `bounds: nil` at
        // the call site compiles and leaves the suite green,
        // because the command test only asserts that the delta
        // SPLIT — which an unbounded split also produces
        // (architect review, 2026-08-29). A float against the
        // region's edge discriminates: bounded, the pinned edge
        // sends the whole delta the other way; unbounded, it
        // splits evenly and runs past the edge.
        let core = makeFloatCore(
            frame: CGRect(
                x: Self.bounds.maxX - 400,
                y: 100,
                width: 400,
                height: 300
            )
        )
        // Animations off so the write is instant and its
        // commanded frame is readable off the #881 stamp,
        // deterministically — the same oracle
        // `FloatResizeAccumulationTests` uses for this path.
        core.tiler.settings.animations.onWindowResize = false
        core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        let frame = core.tiler.recentInstantTarget(WindowID(1))
        #expect(frame?.maxX == Self.bounds.maxX)
        #expect(frame?.minX == Self.bounds.maxX - 500)
    }
}
