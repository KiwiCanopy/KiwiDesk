import AppKit
import Testing

@testable import KiwiDeskCore

/// An App Bar's handle reaching the shelf through the real
/// `updateBars()` (#2567, #3349, #3360): no window, no handle; the
/// revealer's fill reaches it, and a grow reveal starts from it.
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
        "updateBars hands the handle its fill and the shelf its mark",
        .enabled(if: NSScreen.main != nil)
    )
    func shelfReadsTheHandle() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
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
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display.id, edge: .top),
            bar: .app
        )
        let spec = { core.shelves.handles.handleForTesting(key)?.view.spec }
        #expect(spec()?.fill == nil)
        #expect(spec()?.frame.height == ShelfHandleSpec.depth)
        // The revealer's fill reaches the handle it runs along.
        let start = Date(timeIntervalSince1970: 1_000)
        let fill = ShelfHandleSpec.Fill(
            origin: 0.3,
            started: start,
            until: start.addingTimeInterval(1)
        )
        core.shelves.reveal.setFill(key, fill)
        core.updateBars()
        #expect(spec()?.fill == fill)
        let frame = try #require(spec()?.frame)
        // A hidden shelf's panel exists once its bar is revealed.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let overlay = try #require(
            core.shelves.overlayForTesting(display.id, edge: .top)
        )
        // In the shelf's own coordinates: the handle itself.
        #expect(overlay.revealMark?.frame.size == frame.size)
    }

    /// On an edge two Auto bars share, a revealed bar is held over
    /// the run its handle drew along, never a lone bar's centred
    /// run (#3359).
    @Test(
        "a revealed bar is held where its handle ran",
        .enabled(if: NSScreen.main != nil)
    )
    func holdIsWhereTheHandleRan() throws {
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
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        settings.kiwishelf.alignment = .center
        settings.kiwishelf.order = .spacesFirst
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let shelf = ShelfManager.Key(display: display.id, edge: .top)
        let key = ShelfRevealer.Key(shelf: shelf, bar: .app)
        let spec = try #require(
            core.shelves.handles.handleForTesting(key)?.view.spec
        )
        let handle = spec.frame
        // Both handles rest, so the App Bar's is not the lone run.
        #expect(
            core.shelves.handles.handleForTesting(
                .init(shelf: shelf, bar: .space)
            ) != nil
        )
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let held = try #require(core.shelves.reveal.targets[key]?.section)
        #expect(abs(held.minX - handle.minX) < 0.5)
        #expect(abs(held.width - handle.width) < 0.5)
        // It lands in its slot beside the Space Bar's handle, whose
        // run starts where the handle's does — a lone bar's slot
        // would span the edge.
        let bar = try #require(
            core.appBars.shownBarsForTesting.first {
                $0.display == display.id
            }
        )
        #expect(abs(bar.strip.minX - handle.minX) < 0.5)
        #expect(bar.strip.width < screen.frame.width / 2)
    }

    /// Over a maximizing Monocle both bars read Hidden and rest as
    /// handles; a revealed App Bar lands in its share beside the
    /// Space Bar's handle, never a lone bar's whole edge (#3359).
    @Test(
        "over a maximized window a revealed bar takes its share",
        .enabled(if: NSScreen.main != nil)
    )
    func maximizedRevealTakesItsShare() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_104),
                    pid: 900_104,
                    appName: "Max",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_104))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .always
        settings.monocle.appBar.visibility = .always
        settings.monocle.maximizeWindows = true
        settings.kiwishelf.maximizedVisibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        #expect(core.maximizedHoverBars(on: display.id) == [.space, .app])
        core.updateBars()
        // Both hover bars rest as handles over the window.
        let shelf = ShelfManager.Key(display: display.id, edge: .top)
        for bar in [ShelfBar.space, .app] {
            #expect(
                core.shelves.handles.handleForTesting(
                    .init(shelf: shelf, bar: bar)
                ) != nil
            )
        }
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let bar = try #require(
            core.appBars.shownBarsForTesting.first {
                $0.display == display.id
            }
        )
        #expect(bar.strip.width < screen.frame.width / 2)
    }
}
