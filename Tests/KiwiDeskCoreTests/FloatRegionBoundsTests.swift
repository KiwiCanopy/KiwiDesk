import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The float REGION and its two bounds (#1091), split from
/// `FloatRegionFitTests` at §2.1's ceiling rather than after
/// crossing it. That suite keeps the retile fit and the refusal
/// memo; this one owns the derivation and the ring reservation.
///
/// **They are two questions, not one rect with two meanings**
/// (device QA, 2026-08-29). `floatBounds` is the correctness
/// bound — a float larger than it has part of itself under a
/// bar, which is unreachable. `floatGrowBounds` reserves the
/// focus ring's reach on top, because a clipped ring is a
/// blemish rather than an unusable window. Reserving the ring in
/// the correctness bound would make the retile pull in a float
/// the user had resized flush by hand.
@MainActor
@Suite("Float region bounds (#1091)")
struct FloatRegionBoundsTests {
    private static let bounds = CGRect(
        x: 0,
        y: 0,
        width: 1600,
        height: 1000
    )

    private func makeFloatCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-floatbounds-\(UUID().uuidString)"
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
                    frame: CGRect(
                        x: 0,
                        y: 0,
                        width: 400,
                        height: 300
                    ),
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
        "With no bars the grow bound is the display, less the ring",
        .enabled(if: NSScreen.main != nil)
    )
    func growBoundIsTheDisplayLessTheRing() throws {
        // The ring's reach comes off every edge, the screen's
        // included (device QA, 2026-08-29) — a float grown flush
        // to a screen edge had its ring clipped there while
        // being held clear of a bar.
        //
        // Derived from the renderer's own reach rather than
        // pinned at a number: `border.width` is feel and the
        // owner's to retune, so a literal here would red on
        // every retune and catch no regression (#1021).
        let core = makeFloatCore()
        let reach = BorderGeometry.outwardReach(
            width: core.tiler.settings.borderStyle.width
        )
        #expect(reach > 0)
        let region = try #require(
            core.floatGrowBounds(of: WindowID(1))
        )
        #expect(region == Self.bounds.insetBy(dx: reach, dy: reach))
        // ...and it is zero with rings off, which is the escape:
        // nothing is reserved for chrome that is not drawn.
        core.tiler.settings.borderStyle.enabled = false
        #expect(
            core.floatGrowBounds(of: WindowID(1)) == Self.bounds
        )
    }

    @Test(
        "The grow bound reserves the ring; the fit bound does not",
        .enabled(if: NSScreen.main != nil)
    )
    func theTwoBoundsDiffer() throws {
        // The split itself. Collapsing them — reserving the ring
        // in `floatBounds` too — makes the retile fit shrink a
        // float the user resized flush by hand, which is the fit
        // fighting the hand that the rule forbids.
        let core = makeFloatCore()
        let reach = BorderGeometry.outwardReach(
            width: core.tiler.settings.borderStyle.width
        )
        #expect(reach > 0)
        let fit = try #require(core.floatBounds(of: WindowID(1)))
        let grow = try #require(
            core.floatGrowBounds(of: WindowID(1))
        )
        #expect(fit == Self.bounds)
        #expect(grow == fit.insetBy(dx: reach, dy: reach))
    }

    @Test(
        "A bar edge reserves one reach, on the grow bound only",
        .enabled(if: NSScreen.main != nil)
    )
    func aBarEdgeReservesOneReach() throws {
        // Neither of this suite's other fixtures paints a bar,
        // which is exactly how two defects got through
        // (guard-prover, 2026-08-29): the correctness bound was
        // carving a reach at bar strips while its docstring said
        // it reserved none, so the grow bound took TWO there,
        // and the retile fit pulled in a float the user had
        // resized flush against a bar — the fit fighting the
        // hand, surviving on the axis the split forgot.
        let core = makeFloatCore()
        core.appBars.sync([
            paintedAppBar(items: [appBarItem(1, text: "A")])
        ])
        let reach = BorderGeometry.outwardReach(
            width: core.tiler.settings.borderStyle.width
        )
        #expect(reach > 0)

        let fit = try #require(core.floatBounds(of: WindowID(1)))
        let grow = try #require(
            core.floatGrowBounds(of: WindowID(1))
        )
        // The correctness bound stops AT the strip: a window
        // there is reachable, only its ring is covered.
        #expect(fit.minY == barTitleStrip.maxY)
        // The grow bound reserves exactly one reach past it —
        // not two, which is what a carve here plus the uniform
        // inset would give.
        #expect(grow.minY == barTitleStrip.maxY + reach)
        // And the screen edges of the same rects, so the two
        // axes cannot drift apart.
        #expect(fit.maxY == Self.bounds.maxY)
        #expect(grow.maxY == Self.bounds.maxY - reach)
        #expect(grow.minX == Self.bounds.minX + reach)
    }

    @Test(
        "The clamp still pushes a float clear of the bar's ring",
        .enabled(if: NSScreen.main != nil)
    )
    func theClampKeepsTheRingClearOfABar() {
        // The third site the ring inset runs through, and the
        // one that is a POSITION correction rather than a bound:
        // it may reserve the reach because it is already moving
        // the window, so it is not fighting a placement the user
        // chose. Zeroing it left the full suite green.
        let core = makeFloatCore()
        core.appBars.sync([
            paintedAppBar(items: [appBarItem(1, text: "A")])
        ])
        let reach = BorderGeometry.outwardReach(
            width: core.tiler.settings.borderStyle.width
        )
        let under = CGRect(x: 100, y: 0, width: 400, height: 300)
        let clamped = core.floatFrameClampedClearOfBars(
            WindowID(1),
            frame: under
        )
        #expect(clamped.minY == barTitleStrip.maxY + reach)
        #expect(clamped.size == under.size)
    }
}
