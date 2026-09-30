import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The App Bar lists a Space's floats after its tiled row, past
/// the floating mark (#1826): never in `barGroups`, which the drag reorder
/// indexes, and a focused float takes the highlight.
@Suite("App Bar floats", .serialized)
@MainActor
struct AppBarFloatTests {
    /// A monocle Space holding tiled A, B and float F, plus a
    /// transient-overlay float P (a dialog) that is never listed.
    private func makeCore() throws -> (KiwiCore, Space) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-app-bar-floats-\(UUID().uuidString)"
                )
        )
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
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
        return (core, try #require(core.activeSpace))
    }

    private func content(
        _ core: KiwiCore,
        _ space: Space
    ) throws -> KiwiCore.AppBarContent {
        try #require(
            core.appBarContent(
                space: space,
                settings: core.tiler.settings
            )
        )
    }

    @Test("Floats follow the tiled row and stay out of its groups")
    func floatsTrailTheRow() throws {
        let (core, space) = try makeCore()
        let app = try content(core, space)
        #expect(app.groups == [[WindowID(1)], [WindowID(2)]])
        #expect(app.items.map(\.id) == [1, 2, 3].map(WindowID.init))
        #expect(app.items.map(\.floating) == [false, false, true])
    }

    @Test("A focused float takes the highlight, not the anchor")
    func focusedFloatHighlights() throws {
        let (core, _) = try makeCore()
        core.state.apply(.windowFocused(WindowID(1)))
        core.state.apply(.windowFocused(WindowID(3)))
        let app = try content(core, try #require(core.activeSpace))
        #expect(core.appBarActiveIndex(of: app) == 2)
        core.state.apply(.windowFocused(WindowID(2)))
        let tiled = try content(core, try #require(core.activeSpace))
        #expect(core.appBarActiveIndex(of: tiled) == 1)
    }

    /// The bar the shelf places carries that highlight — the
    /// wiring, not only the reading (#1826).
    @Test("The placed bar highlights a focused float")
    func placedBarHighlightsFloat() throws {
        let (core, _) = try makeCore()
        core.state.apply(.windowFocused(WindowID(3)))
        let app = try content(core, try #require(core.activeSpace))
        let plan = try #require(
            core.shelfPlans(
                visible: CGRect(x: 0, y: 0, width: 1440, height: 900),
                settings: core.tiler.settings,
                spaceItems: nil,
                app: app
            ).first
        )
        let bar = try #require(
            core.placedBar(app, display: DisplayID(7), plan: plan)
        )
        #expect(bar.activeIndex == 2)
    }

    @Test("A Space of floats alone still shows its bar")
    func floatsOnly() throws {
        let (core, _) = try makeCore()
        for id in [WindowID(1), WindowID(2)] {
            core.state.apply(.windowDestroyed(id, wasMinimized: false))
        }
        let app = try content(core, try #require(core.activeSpace))
        #expect(app.groups.isEmpty)
        #expect(app.items.map(\.id) == [WindowID(3)])
    }

    @Test("A Space Bar chip draws its floats last")
    func spaceBarFloatsLast() throws {
        let (core, space) = try makeCore()
        let apps = core.spaceBarApps(in: space, style: SpaceBarLook())
            .apps
        #expect(apps.map(\.name) == ["A", "B", "F"])
        #expect(apps.map(\.floating) == [false, false, true])
    }
}
