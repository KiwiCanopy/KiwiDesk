import AppKit
import Testing

@testable import KiwiDeskCore

/// An App Bar's handle reaching the shelf through the real
/// `updateBars()` (#2567, #3349): no window, no handle; the glyphs
/// peek through it, and a grow reveal starts from its thickened
/// plate.
@Suite("App Bar handle wiring (#3349)", .serialized)
@MainActor
struct ShelfHandleWiringTests {
    @Test(
        "An App Bar with no window draws no handle",
        .enabled(if: NSScreen.main != nil)
    )
    func emptyAppBarDrawsNoHandle() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.currentSpace(on: display.id)
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.bottom)
        settings.appBarStyle.setEdge(.top)
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .top)
        #expect(
            core.shelves.handles.handleForTesting(
                .init(shelf: key, bar: .app)
            ) == nil
        )
    }

    @Test(
        "updateBars hands the handle its glyphs and the shelf its plate",
        .enabled(if: NSScreen.main != nil)
    )
    func shelfReadsTheHandle() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        // The fixture's pid has no app; its icon is the glyph.
        let glyph = NSImage(size: CGSize(width: 16, height: 16))
        let before = BarIconCache.read
        BarIconCache.read = { $0 == 900_101 ? glyph : nil }
        defer {
            BarIconCache.read = before
            BarIconCache.forget(pid: 900_101)
            NativeSpaces.currentSpaceIsUserOverride = nil
        }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_101),
                    pid: 900_101,
                    appName: "Growth",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_101))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        // The App Bar alone on its edge, so its handle is the mark.
        settings.spaceBarStyle.setEdge(.bottom)
        settings.appBarStyle.setEdge(.top)
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .top)
        let spec = try #require(
            core.shelves.handles.handleForTesting(
                .init(shelf: key, bar: .app)
            )?.view.spec
        )
        guard case .glyphs(let glyphs) = spec.peek else {
            Issue.record("the App Bar's glyphs peek through")
            return
        }
        #expect(glyphs == [glyph])
        #expect(spec.frame.height == ShelfHandleSpec.depth)
        // A hidden shelf's panel exists once its bar is revealed.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let overlay = try #require(
            core.shelves.overlayForTesting(display.id, edge: .top)
        )
        // In the shelf's own coordinates: the thickened plate.
        #expect(overlay.revealMark?.frame.size == spec.grown.size)
    }

    /// On an edge an Always bar shares, a hidden Auto bar's handle
    /// runs where that bar draws once revealed, never where the
    /// pass that leaves it out would put it (#3349).
    @Test(
        "a hidden bar's handle runs where it draws once revealed",
        .enabled(if: NSScreen.main != nil)
    )
    func handleRunsWhereTheBarDraws() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_102),
                    pid: 900_102,
                    appName: "Pair",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_102))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.reserve = false
        settings.monocle.appBar.visibility = .hidden
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display.id, edge: .top),
            bar: .app
        )
        // A Hidden App Bar draws no handle; its target knows the run.
        let hidden = try #require(
            core.shelves.reveal.targets[key]?.section
        )
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let shown = try #require(core.shelves.reveal.targets[key]?.section)
        #expect(abs(hidden.minX - shown.minX) < 0.5)
        #expect(abs(hidden.width - shown.width) < 0.5)
    }
}
