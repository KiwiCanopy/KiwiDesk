import AppKit
import Testing

@testable import KiwiDeskCore

/// A Hidden bar its shortcut reveals beside a resting Auto sibling
/// is held over the run it lands in (#3359): its target's section
/// is read from the same arrangement that places it, never the
/// drawn bars' alone.
@Suite("A revealed Hidden bar's hold (#3359)", .serialized)
@MainActor
struct ShelfHiddenHoldTests {
    @Test(
        "a revealed Hidden bar is held where it lands",
        .enabled(if: NSScreen.main != nil)
    )
    func holdIsWhereItLands() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_105),
                    pid: 900_105,
                    appName: "Held",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_105))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .hidden
        settings.kiwishelf.order = .spacesFirst
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let key = ShelfRevealer.Key(
            shelf: ShelfManager.Key(display: display.id, edge: .top),
            bar: .app
        )
        let held = try #require(core.shelves.reveal.targets[key]?.section)
        let bar = try #require(
            core.appBars.shownBarsForTesting.first {
                $0.display == display.id
            }
        )
        // The run starts its slot, which follows the Space handle.
        #expect(abs(held.minX - bar.strip.minX) < 0.5)
        #expect(held.maxX <= bar.strip.maxX + 0.5)
        #expect(bar.strip.minX > screen.frame.minX)
    }

    /// A Hidden bar beside an Auto sibling rests as no handle: the
    /// filing hands handles only to the edge's handled bars.
    @Test(
        "a Hidden bar beside an Auto one draws no handle",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenBesideAutoHasNoHandle() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_106),
                    pid: 900_106,
                    appName: "Beside",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_106))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .hidden
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let shelf = ShelfManager.Key(display: display.id, edge: .top)
        // Filed as a hidden target, no handle's.
        #expect(
            core.shelves.reveal.targets[.init(shelf: shelf, bar: .app)]
                != nil
        )
        let handles = core.shelves.handles
        #expect(
            handles.handleForTesting(.init(shelf: shelf, bar: .space)) != nil
        )
        #expect(
            handles.handleForTesting(.init(shelf: shelf, bar: .app)) == nil
        )
        // Revealed, it draws, and still rests as no handle.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        #expect(
            handles.handleForTesting(.init(shelf: shelf, bar: .app)) == nil
        )
    }

}
