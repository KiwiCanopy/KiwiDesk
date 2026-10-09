import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The consumers of the reserved fold (#1524), through the real
/// drivers: the float region follows the edges the layout gives
/// up rather than every strip painted, a bar write that moves no
/// reserved edge issues no pass, and the verbs reach the stored
/// style from Lua and the CLI.
@Suite("Bar reserve consumers (#1524)", .serialized)
@MainActor
struct BarReserveCoreTests {
    private static let window = WindowID(1)

    /// A core on the primary screen, one tiled window in a Space
    /// laid out in `mode`, both bars on the top edge. Nil where
    /// the host has no screen to paint on.
    private func makeCore(
        mode: LayoutMode,
        spaceReserves: Bool,
        appReserves: Bool = true
    ) -> (KiwiCore, SpaceID, NSScreen)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "ReserveApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400),
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(space, mode)
        core.state.workspaces.withSpace(space) {
            $0.focused = Self.window
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

    @Test(
        "A fused edge another bar reserves keeps every float out",
        .enabled(if: NSScreen.main != nil)
    )
    func fusedReservedEdgeCarvesTheWholeStrip() throws {
        let (core, space, _) = try #require(
            makeCore(mode: .monocle, spaceReserves: false)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let spaceStrip = try #require(core.spaceBars.shownStrips.first)
        let region = try #require(core.floatBounds(on: space))
        // Under the Space Bar's own section too, as a tiled
        // window is kept out of it.
        #expect(region.minY >= spaceStrip.strip.maxY)
        // Both bars off it: the strip is free for floats too.
        let (free, freeSpace, screen) = try #require(
            makeCore(
                mode: .monocle,
                spaceReserves: false,
                appReserves: false
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

    @Test(
        "A bar write that moves no reserved edge issues no pass",
        .enabled(if: NSScreen.main != nil)
    )
    func unchangedReservationSkipsTheRetile() throws {
        let (core, _, _) = try #require(
            makeCore(mode: .bsp, spaceReserves: false)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        for (verb, value) in [
            ("space_bar.set_enabled", JSONValue.bool(false)),
            ("space_bar.set_enabled", .bool(true)),
            ("space_bar.set_glyph_span", .number(8)),
            ("app_bar.set_title_cap", .number(30)),
        ] {
            #expect(core.execute(verb, args: [value]).isSuccess)
        }
        #expect(passes(meter) == 0)
        // Reserving moves the edge, so it is an explicit apply.
        #expect(
            core.execute("space_bar.set_reserve", args: [.bool(true)])
                .isSuccess
        )
        #expect(passes(meter) == 1)
    }

    @Test("set_reserve reaches the stored style over the CLI")
    func cliRoundTrip() {
        let core = makeTestCore()
        for bar in ["space_bar", "app_bar"] {
            #expect(
                core.execute("\(bar).set_reserve", args: [.bool(false)])
                    .isSuccess
            )
        }
        #expect(!core.tiler.settings.spaceBarStyle.reserve)
        #expect(!core.tiler.settings.appBarStyle.reserve)
        #expect(
            !core.execute("space_bar.set_reserve", args: [.string("no")])
                .isSuccess
        )
        // Global only: no layout carries its own reservation.
        #expect(
            !core.execute(
                "monocle.set_app_bar_reserve",
                args: [.bool(false)]
            ).isSuccess
        )
    }

    @Test("set_reserve reaches the stored style from Lua")
    func luaRoundTrip() throws {
        let core = makeTestCore()
        let lua = try #require(LuaInterpreter())
        core.registerLuaAPI(on: lua)
        let result = lua.run(
            "space_bar.set_reserve(false)\napp_bar.set_reserve(false)"
        )
        guard case .success = result else {
            Issue.record("set_reserve run failed: \(result)")
            return
        }
        #expect(!core.tiler.settings.spaceBarStyle.reserve)
        #expect(!core.tiler.settings.appBarStyle.reserve)
    }
}
