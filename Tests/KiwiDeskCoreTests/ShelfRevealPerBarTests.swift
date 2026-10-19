import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Each bar keeps its own visibility and a reveal names one bar
/// (#761): a `hidden` bar reserves and draws nothing until its
/// shortcut shows it over the windows, a shortcut on a shared edge
/// shows only the bar it names, and a shortcut on an `always` bar
/// refuses. The edge resolves through `barEdges`' precedence.
@Suite("Shelf reveal per bar (#761)", .serialized)
@MainActor
struct ShelfRevealPerBarTests {
    private static let window = WindowID(900_761)

    // MARK: - The fold

    @Test("an edge reserves for its more present bar")
    func edgeReadsItsMostPresentBar() {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        let pairs: [(ShelfVisibility, ShelfVisibility, ShelfVisibility)] = [
            (.always, .auto, .always),
            (.auto, .hidden, .auto),
            (.hidden, .hidden, .hidden),
            (.hidden, .always, .always),
        ]
        for (space, app, edge) in pairs {
            let folded = settings.barEdges(space: space, app: app)
            #expect(folded.count == 1)
            #expect(folded.first?.visibility == edge)
        }
        let mixed = settings.barEdges(space: .always, app: .auto)[0]
        #expect(mixed.shown(.app) == .always)
        let quiet = settings.barEdges(space: .auto, app: .hidden)[0]
        #expect(quiet.shown(.app) == .hidden)
        #expect(quiet.drawnAtRest.isEmpty)
    }

    @Test("a hidden bar reserves nothing, an auto one its sliver")
    func hiddenReservesNothing() {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .hidden
        let hidden = settings.shelfReservation(in: .bsp, on: nil)
        #expect(hidden.edges.isEmpty)
        #expect(hidden.hiding.isEmpty)
        settings.spaceBarStyle.visibility = .auto
        let auto = settings.shelfReservation(in: .bsp, on: nil)
        #expect(auto.edges.isEmpty)
        #expect(auto.hiding == [.top])
    }

    @Test("the App Bar's value is its layout's own")
    func appBarIsPerLayout() {
        var settings = TilingSettings()
        settings.monocle.appBar.visibility = .always
        settings.scrolling.appBar.visibility = .hidden
        #expect(settings.appBarVisibility(in: .monocle) == .always)
        #expect(settings.appBarVisibility(in: .scrolling) == .hidden)
        #expect(settings.appBarVisibility(in: .bsp) == nil)
        #expect(settings.revealActionLive(.app, in: .scrolling))
        #expect(!settings.revealActionLive(.app, in: .monocle))
        #expect(!settings.revealActionLive(.app, in: .bsp))
    }

    // MARK: - Through the drivers

    /// A core on the primary screen with one window in a monocle
    /// Space, both bars on the top edge at the given values. Nil
    /// where the host has no screen to paint on.
    private func makeCore(
        space: ShelfVisibility,
        app: ShelfVisibility
    ) -> (KiwiCore, DisplayID)? {
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
                    pid: 900_761,
                    appName: "PerBarApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        if let id = core.state.workspaces.space(of: Self.window) {
            core.state.workspaces.setMode(id, .monocle)
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = space
        settings.monocle.appBar.visibility = app
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "A hidden bar draws nothing until its shortcut, which moves no window",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenShowsOnItsShortcut() throws {
        let (core, display) = try #require(
            makeCore(space: .hidden, app: .hidden)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let shelf = ShelfManager.Key(display: display, edge: .top)
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.shelves.indicators.indicatorForTesting(shelf) == nil)
        let target = try #require(
            core.shelves.reveal.targets[.init(shelf: shelf, bar: .space)]
        )
        #expect(!target.hovers)
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.spaceBars.shownStrips.isEmpty)
        let counts = meter.snapshot(reset: false).counts
        #expect(counts.retiles + counts.passesHeld == 0)
    }

    @Test(
        "A shortcut on a shared edge shows only the bar it names",
        .enabled(if: NSScreen.main != nil)
    )
    func shortcutNamesOneBar() throws {
        let (core, _) = try #require(makeCore(space: .hidden, app: .hidden))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.appBars.shownStrips.isEmpty)
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(!core.appBars.shownStrips.isEmpty)
    }

    @Test(
        "A shortcut on an always bar refuses and changes nothing",
        .enabled(if: NSScreen.main != nil)
    )
    func alwaysRefuses() throws {
        let (core, _) = try #require(makeCore(space: .always, app: .hidden))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let before = core.tiler.settings
        #expect(!core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        #expect(core.tiler.settings == before)
        // The Always Space Bar draws; its hidden sibling joins it on
        // its own shortcut.
        #expect(core.appBars.shownStrips.isEmpty)
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.appBars.shownStrips.isEmpty)
    }
}
