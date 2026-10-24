import AppKit
import Testing

@testable import KiwiDeskCore

/// Where the App Bar handle's count comes from (#2567 ▸
/// Ruling): the App Bar's own content — its groups' windows and its
/// floats, a transient dialog left out — reaching the handle through
/// the real `updateBars()`. The number's baseline is
/// `BarTextBaselineSiteTests` ▸ `handleCountLine`.
@Suite("App Bar handle count wiring (#2567)", .serialized)
@MainActor
struct ShelfHandleCountWiringTests {
    /// A monocle Space holding tiled A, B, float F and a dialog.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-markcount-\(UUID().uuidString)")
        )
        core.execute("set_mode", args: [.string("1"), .string("monocle")])
        var dialog = ManagedWindow(
            id: WindowID(4),
            pid: 4,
            appName: "P",
            isFloating: true
        )
        dialog.isTransientOverlay = true
        for window in [
            ManagedWindow(id: WindowID(1), pid: 1, appName: "A"),
            ManagedWindow(
                id: WindowID(3),
                pid: 3,
                appName: "F",
                isFloating: true
            ),
            ManagedWindow(id: WindowID(2), pid: 2, appName: "B"),
            dialog,
        ] {
            core.state.apply(.windowCreated(window))
        }
        return core
    }

    @Test("The count is every window the App Bar draws")
    func countIsTheBars() throws {
        let core = makeCore()
        let space = try #require(core.activeSpace)
        let app = try #require(
            core.appBarContent(space: space, settings: core.tiler.settings)
        )
        let drawn =
            Set(app.groups.flatMap { $0 })
            .union(app.items.filter(\.floating).map(\.id))
        #expect(app.windowCount == drawn.count)
        #expect(app.windowCount == 3)
    }

    @Test(
        "updateBars hands the App Bar handle its count",
        .enabled(if: NSScreen.main != nil)
    )
    func markReadsTheCount() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        for (id, floating) in [(1, false), (2, false), (3, true)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(900_000 + id)),
                        pid: pid_t(900_000 + id),
                        appName: "Count\(id)",
                        frame: CGRect(x: 100, y: 200, width: 600, height: 400),
                        isFloating: floating
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: WindowID(900_001))
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .top)
        let view = try #require(
            core.shelves.handles.handleForTesting(
                .init(shelf: key, bar: .app)
            )?.view
        )
        let shown = try #require(core.state.workspaces[space])
        let app = try #require(
            core.appBarContent(space: shown, settings: core.tiler.settings)
        )
        #expect(app.windowCount == 3)
        #expect(view.spec?.count?.windows == app.windowCount)
        // The count is handed the badge face, not the name's.
        #expect(
            view.spec?.count?.font
                == KiwiCore.HidingShelves.markCountFont(core.tiler.settings)
        )
    }

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

    /// A grow reveal starts from the plate on screen: the mark grown
    /// by its handle's own growth, never the plain hover.
    @Test("A reveal grows out of the handle's own grown plate")
    func revealStartsFromTheGrownPlate() throws {
        let mark = CGRect(x: 100, y: 0, width: 36, height: 8)
        let growth = ShelfHandleSpec.Growth(widen: 10, across: 0)
        var path = BarMotion.RevealPath(kind: .grow)
        path.origin = mark
        path.growth = growth
        path.plate = CGRect(x: 0, y: 0, width: 600, height: 30)
        path.edge = .top
        guard
            case .morph(let morph) = BarMotion.revealMotion(
                entering: true,
                path: path
            )
        else {
            Issue.record("a grow plays no morph")
            return
        }
        #expect(
            morph.mark
                == BarMotion.hoverPlate(
                    mark: mark,
                    growth: growth,
                    edge: .top,
                    hovered: true
                )
        )
    }

    @Test(
        "updateBars hands the shelf its handle's growth",
        .enabled(if: NSScreen.main != nil)
    )
    func shelfReadsTheGrowth() throws {
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
        let key = ShelfManager.Key(display: display.id, edge: .top)
        let spec = try #require(
            core.shelves.handles.handleForTesting(
                .init(shelf: key, bar: .app)
            )?.view.spec
        )
        #expect(spec.growth != .none)
        // A hidden shelf's panel exists once its bar is revealed.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        let overlay = try #require(
            core.shelves.overlayForTesting(display.id, edge: .top)
        )
        #expect(overlay.revealMark?.growth == spec.growth)
    }
}
