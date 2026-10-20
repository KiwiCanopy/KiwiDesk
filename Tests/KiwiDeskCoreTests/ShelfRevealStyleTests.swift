import AppKit
import Testing

@testable import KiwiDeskCore

/// Which reveals take the reveal's own motion, and which motion
/// (#2497, owner rulings 2026-10-21): a bar shown onto an EMPTY edge
/// slides or grows — Hidden as well as Auto — while one shown beside
/// an always sibling joins it; and `kiwishelf.set_reveal_style`
/// picks slide or grow for every reveal, slide by default.
@Suite("Shelf reveal style (#2497)", .serialized)
@MainActor
struct ShelfRevealStyleTests {
    private static let window = WindowID(900_840)

    @Test("A reveal onto an empty edge takes the motion; beside Always, joins")
    func emptyEdgeDecides() {
        let cases: [([ShelfBar: ShelfVisibility], Bool)] = [
            ([.space: .hidden], true),
            ([.space: .auto], true),
            ([.space: .auto, .app: .hidden], true),
            ([.space: .hidden, .app: .hidden], true),
            ([.space: .always, .app: .hidden], false),
            ([.space: .hidden, .app: .always], false),
            ([.space: .auto, .app: .always], false),
        ]
        for (bars, slides) in cases {
            let edge = ShelfEdge(.top, reserves: true, bars: bars)
            #expect(edge.drawsNothingAtRest == slides, "\(bars)")
        }
    }

    /// A core with one window in a monocle Space, both bars on the
    /// top edge at the given values. Nil where the host has no
    /// screen to paint on.
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
                    pid: 900_840,
                    appName: "StyleApp",
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
        "A lone Hidden bar's shortcut reveal slides; beside Always it joins",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenSlidesThroughTheDrivers() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (alone, display) = try #require(
            makeCore(space: .hidden, app: .hidden)
        )
        #expect(alone.execute("space_bar.toggle_reveal", args: []).isSuccess)
        let slid = try #require(
            alone.shelves.overlayForTesting(display, edge: .top)
        )
        #expect(slid.slides)
        let (beside, _) = try #require(
            makeCore(space: .always, app: .hidden)
        )
        #expect(beside.execute("app_bar.toggle_reveal", args: []).isSuccess)
        let joined = try #require(
            beside.shelves.overlayForTesting(display, edge: .top)
        )
        #expect(!joined.slides)
    }

    @Test(
        "The verb picks the style every reveal plays, slide by default",
        .enabled(if: NSScreen.main != nil)
    )
    func verbPicksTheStyle() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeCore(space: .auto, app: .hidden)
        )
        #expect(core.tiler.settings.kiwishelf.revealStyle == .slide)
        #expect(
            core.execute("kiwishelf.set_reveal_style", args: [.string("grow")])
                .isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.revealStyle == .grow)
        #expect(
            !core.execute("kiwishelf.set_reveal_style", args: [.string("fly")])
                .isSuccess
        )
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        let overlay = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        #expect(overlay.revealPath.kind == .grow)
        // The mark keeps time with the grow.
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display, edge: .top),
            bar: .space
        )
        #expect(
            core.shelves.indicators.indicatorForTesting(key)?.view.spec?
                .reveal == .grow
        )
    }

    @Test(
        "A Hidden bar's grow starts at its screen side, having no mark",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenGrowStartsAtTheScreenSide() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let (core, display) = try #require(
            makeCore(space: .hidden, app: .hidden)
        )
        core.tiler.settings.kiwishelf.revealStyle = .grow
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        let overlay = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        #expect(overlay.revealOrigin == nil)
        #expect(
            overlay.revealPath.origin
                == ShelfOverlay.screenSide(of: overlay.restRoom, edge: .top)
        )
    }

    @Test("A bundled look never changes the reveal style")
    func lookKeepsTheStyle() {
        for look in LookCatalog.bundled(sizes: [
            CGSize(width: 1728, height: 1117)
        ]) {
            var settings = TilingSettings()
            settings.kiwishelf.revealStyle = .grow
            look.apply(to: &settings)
            #expect(settings.kiwishelf.revealStyle == .grow, "\(look.name)")
        }
    }

    @Test("A missing reveal_style reads slide; a stored one round-trips")
    func storedStyle() throws {
        let empty = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(empty.revealStyle == .slide)
        var shelf = KiwiShelf()
        shelf.revealStyle = .grow
        let data = try JSONEncoder().encode(shelf)
        #expect(String(decoding: data, as: UTF8.self).contains("reveal_style"))
        #expect(try JSONDecoder().decode(KiwiShelf.self, from: data) == shelf)
    }
}
