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
            core.shelves.indicators.indicatorForTesting(
                .init(shelf: key, bar: .app)
            )?.view
        )
        let shown = try #require(core.state.workspaces[space])
        let app = try #require(
            core.appBarContent(space: shown, settings: core.tiler.settings)
        )
        #expect(app.windowCount == 3)
        #expect(view.spec?.count?.windows == app.windowCount)
    }
}
