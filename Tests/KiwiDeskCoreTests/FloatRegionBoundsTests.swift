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
}
