import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The consumers of the reserved fold (#1524), through the real
/// drivers: the float region follows the edges the layout gives
/// up rather than every strip painted, and a bar write that
/// leaves the layout bounds alone repaints the bars and re-clamps
/// the floats without a pass.
@Suite("Bar reserve consumers (#1524)", .serialized)
@MainActor
struct BarReserveCoreTests {
    private static let window = WindowID(1)

    /// A core on the primary screen, its shown Space laid out in
    /// `mode`, both bars on the top edge. `window` places one
    /// window there at `frame` (nil: the Space stays empty). Nil
    /// where the host has no screen to paint on.
    private func makeCore(
        mode: LayoutMode,
        spaceReserves: Bool,
        appReserves: Bool = true,
        window frame: CGRect? = CGRect(
            x: 100,
            y: 200,
            width: 600,
            height: 400
        ),
        floating: Bool = false
    ) -> (KiwiCore, SpaceID, NSScreen)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        if let frame {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: Self.window,
                        pid: 1,
                        appName: "ReserveApp",
                        frame: frame,
                        isFloating: floating
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        guard
            let space = frame == nil
                ? core.state.workspaces.currentSpace(on: display.id)
                : core.state.workspaces.space(of: Self.window)
        else { return nil }
        core.state.workspaces.setMode(space, mode)
        if frame != nil {
            core.state.workspaces.withSpace(space) {
                $0.focused = Self.window
            }
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = true
        settings.spaceBarStyle.reserve = spaceReserves
        settings.appBarStyle.reserve = appReserves
        settings.monocle.appBar.enabled = true
        settings.barEdge = .top
        settings.kiwishelf.thickness = 40
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, space, screen)
    }

    @Test(
        "A Space Bar over the windows keeps no float out",
        .enabled(if: NSScreen.main != nil)
    )
    func floatRegionFollowsReserve() throws {
        let (free, freeSpace, screen) = try #require(
            makeCore(mode: .floating, spaceReserves: false)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The bar still draws: shown is not reserved.
        let painted = try #require(free.spaceBars.shownStrips.first)
        #expect(painted.strip.height > 0)
        #expect(
            free.floatBounds(on: freeSpace)
                == free.tiler.visibleBounds(screen)
        )
        let (held, heldSpace, _) = try #require(
            makeCore(mode: .floating, spaceReserves: true)
        )
        let region = try #require(held.floatBounds(on: heldSpace))
        let strip = try #require(held.spaceBars.shownStrips.first)
        #expect(region.minY >= strip.strip.maxY)
    }

    /// Separates the per-EDGE fold from per-SECTION filtering:
    /// on an empty monocle Space the reserving App Bar paints no
    /// strip, so only the non-reserving Space Bar's section is
    /// there to carve. The fold keeps it, since the layout
    /// reserves that edge; a section filter would carve nothing.
    @Test(
        "A fused edge the unpainted App Bar reserves keeps floats out",
        .enabled(if: NSScreen.main != nil)
    )
    func fusedEdgeFoldCarvesUnpaintedReserver() throws {
        let (core, space, screen) = try #require(
            makeCore(mode: .monocle, spaceReserves: false, window: nil)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(core.appBars.shownStrips.isEmpty)
        let strip = try #require(core.spaceBars.shownStrips.first)
        #expect(
            core.tiler.settings.shelfEdges(in: .monocle, on: nil) == [.top]
        )
        let region = try #require(core.floatBounds(on: space))
        #expect(region.minY >= strip.strip.maxY)
        // Both bars off it: the strip is free for floats too.
        let (free, freeSpace, _) = try #require(
            makeCore(
                mode: .monocle,
                spaceReserves: false,
                appReserves: false,
                window: nil
            )
        )
        #expect(
            free.floatBounds(on: freeSpace)
                == free.tiler.visibleBounds(screen)
        )
    }

    /// Passes the trailing dispatch ran or held.
    private func passes(_ meter: WorkMeter) -> Int {
        let counts = meter.snapshot(reset: false).counts
        return counts.retiles + counts.passesHeld
    }

    private func renders(_ meter: WorkMeter) -> Int {
        meter.snapshot(reset: false).counts.barRenders
    }

    @Test(
        "A bar write that leaves the bounds alone repaints, no pass",
        .enabled(if: NSScreen.main != nil)
    )
    func unchangedReservationSkipsTheRetile() throws {
        let (core, _, _) = try #require(
            makeCore(mode: .bsp, spaceReserves: false)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        #expect(
            core.execute("space_bar.set_enabled", args: [.bool(false)])
                .isSuccess
        )
        // The repaint ran: the hidden bar left the screen.
        #expect(core.spaceBars.shownStrips.isEmpty)
        for (verb, value) in [
            ("space_bar.set_enabled", JSONValue.bool(true)),
            ("space_bar.set_glyph_span", .number(8)),
            ("app_bar.set_title_cap", .number(30)),
        ] {
            let before = renders(meter)
            #expect(core.execute(verb, args: [value]).isSuccess)
            #expect(renders(meter) > before, "\(verb) did not repaint")
        }
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(passes(meter) == 0)
        // Reserving moves the edge, so it is an explicit apply.
        #expect(
            core.execute("space_bar.set_reserve", args: [.bool(true)])
                .isSuccess
        )
        #expect(passes(meter) == 1)
    }

    @Test(
        "A skipped pass still clamps a float under a reserved strip",
        .enabled(if: NSScreen.main != nil)
    )
    func skippedPassReclampsFloats() throws {
        let screen = try #require(NSScreen.screens.first)
        // Overlapping the top strip by construction.
        let (core, _, _) = try #require(
            makeCore(
                mode: .bsp,
                spaceReserves: true,
                window: CGRect(
                    x: screen.frame.minX + 100,
                    y: screen.frame.minY,
                    width: 400,
                    height: 300
                ),
                floating: true
            )
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let strip = try #require(core.spaceBars.shownStrips.first)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        #expect(
            core.execute("space_bar.set_glyph_span", args: [.number(8)])
                .isSuccess
        )
        #expect(passes(meter) == 0)
        let commanded = try #require(
            core.tiler.recentInstantTarget(Self.window),
            "the skipped pass never re-clamped the float"
        )
        #expect(commanded.minY >= strip.strip.maxY)
    }
}
