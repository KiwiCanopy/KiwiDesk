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

    /// A `hidden` bar's target has no band: the pointer never
    /// opens it, no monitor listens for it, and its shortcut does.
    @Test("a band-less target opens on its shortcut alone")
    func bandlessOpensOnTheShortcut() {
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
            bar: .app
        )
        let revealer = ShelfRevealer()
        revealer.makeMonitor = { _ in nil }
        revealer.schedule = { _, _ in ShelfRevealTimer() }
        revealer.location = { CGPoint(x: 500, y: 799) }
        revealer.sync([
            key: ShelfRevealer.Target(
                edge: .top,
                strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                band: nil
            )
        ])
        revealer.start()
        defer { revealer.stop() }
        revealer.moved(to: CGPoint(x: 500, y: 799))
        #expect(revealer.reveal(of: key) == .hidden)
        #expect(!revealer.isListening)
        #expect(revealer.toggle(key, duration: 0))
        #expect(revealer.reveal(of: key) == .pinned(until: nil))
    }

    /// A timed pin on a band-less bar ends hidden whatever the
    /// pointer does, since no hover can ever retract it: under the
    /// pointer at once, and while a menu holds it once released.
    @Test("a timed pin on a hidden bar never strands it shown")
    func bandlessPinEnds() {
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: DisplayID(1), edge: .top),
            bar: .space
        )
        let revealer = ShelfRevealer()
        final class Hold { var on = false }
        var due: [() -> Void] = []
        let hold = Hold()
        revealer.makeMonitor = { _ in nil }
        revealer.schedule = { _, body in
            due.append(body)
            return ShelfRevealTimer()
        }
        revealer.holds = { _ in hold.on }
        // Resting on the strip, inside the zone.
        revealer.location = { CGPoint(x: 500, y: 780) }
        revealer.sync([
            key: ShelfRevealer.Target(
                edge: .top,
                strip: CGRect(x: 0, y: 760, width: 1000, height: 40),
                screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
                band: nil
            )
        ])
        revealer.start()
        defer { revealer.stop() }
        func fire() {
            let now = due
            due = []
            now.forEach { $0() }
        }
        #expect(revealer.toggle(key, duration: 2))
        fire()
        #expect(revealer.reveal(of: key) == .hidden)
        hold.on = true
        #expect(revealer.toggle(key, duration: 2))
        fire()
        #expect(revealer.reveal(of: key).isShown)
        hold.on = false
        fire()
        #expect(revealer.reveal(of: key) == .hidden)
    }

    /// A hidden bar's `reserve` never reserves: an edge's strip is
    /// asked by the bars that draw on it (#1524).
    @Test("a hidden bar's reserve reserves nothing beside its sibling")
    func hiddenReserveReservesNothing() {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .hidden
        settings.spaceBarStyle.reserve = true
        settings.appBarStyle.reserve = false
        settings.monocle.appBar.visibility = .always
        let always = settings.shelfReservation(in: .monocle, on: nil)
        #expect(always.edges.isEmpty)
        #expect(always.hiding.isEmpty)
        settings.monocle.appBar.visibility = .auto
        let auto = settings.shelfReservation(in: .monocle, on: nil)
        #expect(auto.edges.isEmpty)
        #expect(auto.hiding.isEmpty)
    }

    /// An `auto` bar beside an `always` one reads `always`, so a
    /// reserving `auto` bar asks the full strip, never a sliver on
    /// an edge that does not hide — whichever of the two reserves.
    @Test("an auto bar beside an always one reserves the full strip")
    func autoBesideAlwaysReservesFull() {
        for spaceAlways in [true, false] {
            var settings = TilingSettings()
            settings.spaceBarStyle.setEdge(.top)
            settings.appBarStyle.setEdge(.top)
            settings.spaceBarStyle.visibility = spaceAlways ? .always : .auto
            settings.monocle.appBar.visibility = spaceAlways ? .auto : .always
            settings.spaceBarStyle.reserve = !spaceAlways
            settings.appBarStyle.reserve = spaceAlways
            let reserved = settings.shelfReservation(in: .monocle, on: nil)
            #expect(reserved.edges == [.top])
            #expect(reserved.hiding.isEmpty)
        }
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
        for bar in [ShelfBar.space, .app] {
            #expect(
                core.shelves.handles.handleForTesting(
                    .init(shelf: shelf, bar: bar)
                ) == nil
            )
        }
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
        // The refusal names its reason: an `always` bar has no target
        // either, so a bare failure would not tell the gate apart.
        let refused = core.execute("space_bar.toggle_reveal", args: [])
        #expect(refused.error == "the Space Bar is set to always")
        #expect(core.tiler.settings == before)
        // The Always Space Bar draws; its hidden sibling joins it on
        // its own shortcut.
        #expect(core.appBars.shownStrips.isEmpty)
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.appBars.shownStrips.isEmpty)
    }

    @Test(
        "An auto bar beside an always one refuses its shortcut",
        .enabled(if: NSScreen.main != nil)
    )
    func autoBesideAlwaysRefuses() throws {
        let (core, _) = try #require(makeCore(space: .auto, app: .always))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // It reads `always` on the edge: shown, and no target.
        #expect(!core.spaceBars.shownStrips.isEmpty)
        let refused = core.execute("space_bar.toggle_reveal", args: [])
        #expect(
            refused.error == "the Space Bar is shown beside an always bar"
        )
        #expect(!core.spaceBars.shownStrips.isEmpty)
    }
}
