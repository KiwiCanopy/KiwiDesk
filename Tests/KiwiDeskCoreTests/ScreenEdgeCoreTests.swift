import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's edge per screen (#1948) through the real paths: the
/// engine's layout bounds, the live plan each display draws, and
/// the skipped-pass comparison, which must cover the screen axis
/// or a write moving one screen's strip skips the pass it owes.
@Suite("Per-screen bar edges, core (#1948)", .serialized)
@MainActor
struct ScreenEdgeCoreTests {
    private static let window = WindowID(1)
    /// A second display no `NSScreen` backs: it widens the
    /// connected set past one screen, and draws nothing.
    private static let ghost = Display(
        id: DisplayID(9_948),
        name: "Ghost",
        frame: CGRect(x: 90_000, y: 0, width: 800, height: 600)
    )

    /// A core on the primary screen, one window in a Space laid
    /// out in `mode`, both bars on and on the top edge. `ghost`
    /// connects `Self.ghost` too. Nil where the host has no
    /// screen to paint on.
    private func makeCore(
        mode: LayoutMode,
        ghost: Bool = false
    ) -> (KiwiCore, Display, NSScreen)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.shelves.ordersPanels = true
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.screenFingerprint = { _ in display.fingerprint }
        core.state.apply(
            .displaysChanged(ghost ? [display, Self.ghost] : [display])
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "EdgeApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400),
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        guard let space = core.state.workspaces.space(of: Self.window)
        else { return nil }
        core.state.workspaces.setMode(space, mode)
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = true
        settings.scrolling.appBar.enabled = true
        settings.barEdge = .top
        settings.kiwishelf.thickness = 40
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display, screen)
    }

    @Test(
        "The engine's bounds reserve the edge THIS screen has",
        .enabled(if: NSScreen.main != nil)
    )
    func layoutBoundsPerScreen() throws {
        let screen = try #require(NSScreen.screens.first)
        let core = makeTestCore()
        let visible = CGRect(x: 0, y: 0, width: 1200, height: 900)
        core.tiler.visibleBounds = { _ in visible }
        core.tiler.settings.barEdge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        core.tiler.settings.spaceBarStyle.setEdge(.left, on: "A:1x1")
        let space = Space(id: SpaceID("1"), mode: .bsp)
        core.tiler.screenFingerprint = { _ in "A:1x1" }
        let onA = core.tiler.layoutBounds(on: screen, for: space)
        core.tiler.screenFingerprint = { _ in "B:1x1" }
        let onB = core.tiler.layoutBounds(on: screen, for: space)
        let reserve = core.tiler.settings.kiwishelf.reservation
        #expect(onA.minX == visible.minX + reserve)
        #expect(onA.minY == visible.minY)
        #expect(onB.minX == visible.minX)
        #expect(onB.minY == visible.minY + reserve)
    }

    @Test(
        "Each display's plan draws the edges that screen has",
        .enabled(if: NSScreen.main != nil)
    )
    func livePlanPerDisplay() throws {
        let (core, display, _) = try #require(makeCore(mode: .scrolling))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // Another screen's edge leaves this one on the bar's.
        core.tiler.settings.spaceBarStyle.setEdge(.left, on: "Other:1x1")
        core.updateBars()
        #expect(core.spaceBars.shownStrips.first?.edge == .top)
        core.tiler.settings.spaceBarStyle.setEdge(
            .left,
            on: display.fingerprint
        )
        core.updateBars()
        let space = try #require(core.spaceBars.shownStrips.first)
        let app = try #require(core.appBars.shownStrips.first)
        #expect(space.edge == .left)
        #expect(app.edge == .top)
        #expect(
            core.shelves.overlayForTesting(display.id, edge: .left)
                != nil
        )
        #expect(
            core.appBars.shownOverlay(on: display.id)?.root.superview
                === core.shelves.overlayForTesting(display.id, edge: .top)?
                .stripView
        )
    }

    /// The float region carves the strips on the edges THIS
    /// screen reserves, so a Space Bar moved to the left on this
    /// screen alone keeps floats out of the left strip.
    @Test(
        "The float region follows the edge this screen has",
        .enabled(if: NSScreen.main != nil)
    )
    func floatRegionPerScreen() throws {
        let (core, display, _) = try #require(makeCore(mode: .floating))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.settings.spaceBarStyle.setEdge(
            .left,
            on: display.fingerprint
        )
        core.updateBars()
        let space = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        let strip = try #require(core.spaceBars.shownStrips.first)
        #expect(strip.edge == .left)
        let region = try #require(core.floatBounds(on: space))
        #expect(region.minX >= strip.strip.maxX)
    }

    private func passes(_ meter: WorkMeter) -> Int {
        let counts = meter.snapshot(reset: false).counts
        return counts.retiles + counts.passesHeld
    }

    /// `BarReserveCoreTests` ▸ `unchangedReservationSkipsTheRetile`
    /// widened by the screen axis: the bars' own edges stay put,
    /// one connected screen's strip moves, so the pass is owed.
    @Test(
        "A write moving one screen's strip owes the pass",
        .enabled(if: NSScreen.main != nil)
    )
    func screenWriteOwesThePass() throws {
        let (core, display, _) = try #require(
            makeCore(mode: .bsp, ghost: true)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        // A screen that is not connected moves no strip.
        #expect(
            core.execute(
                "space_bar.set_edge",
                args: [.string("right"), .string("Elsewhere:640x480")]
            ).isSuccess
        )
        #expect(passes(meter) == 0)
        #expect(
            core.execute(
                "space_bar.set_edge",
                args: [.string("left"), .string(display.fingerprint)]
            ).isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        #expect(passes(meter) == 1)
    }
}
