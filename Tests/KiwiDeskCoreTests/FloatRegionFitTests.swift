import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float REGION and the retile-time fit into it (#1091).
///
/// Both were unguarded when they landed: deleting the size fit,
/// and separately neutralising the ring inset at all three
/// sites, each left the whole 4239-test suite green
/// (guard-prover, 2026-08-29). The pure geometry beneath them is
/// `FloatClampTests` and `FloatSymmetricResizeTests`; this suite
/// is the `KiwiCore` altitude, where the region is derived and
/// the fit is applied.
@MainActor
@Suite("Float region and retile fit (#1091)")
struct FloatRegionFitTests {
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
            configDirectory: FileManager.default
                .temporaryDirectory
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
        "With no bars the region is the display",
        .enabled(if: NSScreen.main != nil)
    )
    func regionIsTheDisplayWithNoBars() throws {
        let core = makeFloatCore(
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
        let region = try #require(core.floatBounds(of: WindowID(1)))
        #expect(region == Self.bounds)
    }

    @Test(
        "An oversized float is fitted back into the region",
        .enabled(if: NSScreen.main != nil)
    )
    func oversizedFloatIsFitted() {
        // The case the owner hit: `clampClear` only ever wrote
        // `origin`, so a float grown past the region was pushed
        // to one side and still overflowed. Deleting the fit
        // reds here and nowhere else.
        let core = makeFloatCore(
            frame: CGRect(x: 0, y: 0, width: 2400, height: 1600)
        )
        let fitted = core.floatFrameFittedClearOfBars(
            WindowID(1),
            frame: CGRect(x: 0, y: 0, width: 2400, height: 1600)
        )
        #expect(fitted.width == Self.bounds.width)
        #expect(fitted.height == Self.bounds.height)
    }

    @Test(
        "A float inside the region is left exactly alone",
        .enabled(if: NSScreen.main != nil)
    )
    func fittedIsANoOpInsideTheRegion() {
        let frame = CGRect(x: 200, y: 150, width: 400, height: 300)
        let core = makeFloatCore(frame: frame)
        #expect(
            core.floatFrameFittedClearOfBars(
                WindowID(1),
                frame: frame
            ) == frame
        )
    }

    @Test(
        "A sub-tolerance overflow is left alone, not re-fitted",
        .enabled(if: NSScreen.main != nil)
    )
    func subToleranceOverflowDoesNotWobble() {
        // The fit runs on EVERY retile, so correcting a
        // sub-point overflow would rewrite the frame forever —
        // the wobble `AppBarGeometry.clampTolerance` exists for,
        // and the reason the clamp beside it is gated the same
        // way.
        let over =
            Self.bounds.width
            + AppBarGeometry.clampTolerance / 2
        let frame = CGRect(x: 0, y: 0, width: over, height: 300)
        let core = makeFloatCore(frame: frame)
        #expect(
            core.floatFrameFittedClearOfBars(
                WindowID(1),
                frame: frame
            ).width == over
        )
    }

    @Test(
        "The fit bounds the SIZE and never the position",
        .enabled(if: NSScreen.main != nil)
    )
    func positionStaysTheUsers() {
        // The ruled half: this net runs for every float on every
        // retile, so it must not drag back a window the user
        // parked half off-screen by hand.
        let frame = CGRect(
            x: Self.bounds.maxX - 100,
            y: 100,
            width: 400,
            height: 300
        )
        let core = makeFloatCore(frame: frame)
        let fitted = core.floatFrameFittedClearOfBars(
            WindowID(1),
            frame: frame
        )
        #expect(fitted.origin == frame.origin)
        #expect(fitted.size == frame.size)
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

    @Test(
        "The floor outranks the region when they contradict",
        .enabled(if: NSScreen.main != nil)
    )
    func theFloorWinsAgainstANarrowRegion() {
        // Bar thickness has a lower clamp and no upper one, so a
        // deep enough bar leaves a region narrower than
        // `min_window_size` — and at the limit a zero-extent
        // one, which AppKit rejects outright. Leave the window
        // oversized rather than write a frame it cannot have;
        // scrolling rules the same clash the same way (code
        // review, 2026-08-29).
        let frame = CGRect(x: 0, y: 0, width: 900, height: 800)
        let core = makeFloatCore(frame: frame)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 120, height: 90)
        }
        core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        let fitted = core.floatFrameFittedClearOfBars(
            WindowID(1),
            frame: frame
        )
        #expect(fitted.width == 300)
        #expect(fitted.height == 300)
    }

    @Test(
        "A refused fit is asked once, then not again",
        .enabled(if: NSScreen.main != nil)
    )
    func aRefusedFitStopsBeingReAsked() {
        // The memo's EFFECT, not its algebra. `FloatFitLedgerTests`
        // builds its own ledger value and structurally cannot see
        // the consumer — deleting the consultation left all 4259
        // tests green (guard-prover, 2026-08-29).
        let current = CGRect(x: 0, y: 0, width: 900, height: 800)
        let fitted = CGRect(x: 0, y: 0, width: 600, height: 500)
        let core = makeFloatCore(frame: current)
        let id = WindowID(1)
        // First sweep asks.
        #expect(
            core.shouldIssueFloatFit(
                id,
                current: current,
                fitted: fitted
            )
        )
        // The app refused, so the window still reports the old
        // size: the second sweep must NOT re-ask.
        #expect(
            !core.shouldIssueFloatFit(
                id,
                current: current,
                fitted: fitted
            )
        )
        // Either half moving is a fresh question — here the app
        // changed its own mind.
        let moved = CGRect(x: 0, y: 0, width: 880, height: 800)
        #expect(
            core.shouldIssueFloatFit(
                id,
                current: moved,
                fitted: fitted
            )
        )
    }

    @Test(
        "A position-only correction is never memoed away",
        .enabled(if: NSScreen.main != nil)
    )
    func positionOnlyCorrectionsAlwaysIssue() {
        // A move is nearly always accepted, so it converges
        // without a memo — which is why the clamp this sits
        // beside never needed one. Memoing it would stop the bar
        // clamp re-asserting itself.
        let current = CGRect(x: 0, y: 0, width: 400, height: 300)
        let moved = CGRect(x: 40, y: 40, width: 400, height: 300)
        let core = makeFloatCore(frame: current)
        for _ in 0..<3 {
            #expect(
                core.shouldIssueFloatFit(
                    WindowID(1),
                    current: current,
                    fitted: moved
                )
            )
        }
    }
}
