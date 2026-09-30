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
        #expect(app.floats == [WindowID(3)])
        #expect(app.items.map(\.id) == [1, 2, 3].map(WindowID.init))
        #expect(app.items.map(\.floating) == [false, false, true])
    }

    @Test("A focused float takes the highlight, not the anchor")
    func focusedFloatHighlights() throws {
        let (core, _) = try makeCore()
        core.state.apply(.windowFocused(WindowID(1)))
        core.state.apply(.windowFocused(WindowID(3)))
        let app = try content(core, try #require(core.activeSpace))
        #expect(core.appBarFloatHighlight(of: app) == 2)
        core.state.apply(.windowFocused(WindowID(2)))
        let tiled = try content(core, try #require(core.activeSpace))
        #expect(core.appBarFloatHighlight(of: tiled) == nil)
    }

    @Test("A Space of floats alone still shows its bar")
    func floatsOnly() throws {
        let (core, _) = try makeCore()
        for id in [WindowID(1), WindowID(2)] {
            core.state.apply(.windowDestroyed(id, wasMinimized: false))
        }
        let app = try content(core, try #require(core.activeSpace))
        #expect(app.groups.isEmpty)
        #expect(app.floats == [WindowID(3)])
    }

    @Test("A Space Bar chip draws its floats last")
    func spaceBarFloatsLast() throws {
        let (core, space) = try makeCore()
        let apps = core.spaceBarApps(in: space, style: SpaceBarLook())
            .apps
        #expect(apps.map(\.name) == ["A", "B", "F"])
        #expect(apps.map(\.floating) == [false, false, true])
    }

    // MARK: - The overlay

    private func item(_ id: UInt32, floating: Bool = false)
        -> AppBarOverlay.Item
    {
        AppBarOverlay.Item(
            id: WindowID(id),
            name: "App\(id)",
            text: "App\(id)",
            icon: nil,
            floating: floating
        )
    }

    private func show(
        _ overlay: AppBarOverlay,
        _ items: [AppBarOverlay.Item]
    ) {
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 800, height: 30),
            style: AppBarLook()
        )
    }

    @Test("The floating mark sits between the row and a float")
    func markBetweenSections() throws {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2), item(3, floating: true)])
        let mark = overlay.floatMark
        #expect(!mark.isHidden)
        #expect(mark.superview === overlay.itemRun)
        #expect(!mark.isAccessibilityElement())
        #expect(mark.hitTest(CGPoint(x: mark.frame.midX, y: 1)) == nil)
        let tiled = overlay.itemViews[1].frame
        let float = overlay.itemViews[2].frame
        #expect(mark.frame.minX > tiled.maxX)
        #expect(mark.frame.maxX < float.minX)
        // Every item keeps the one slot length; the mark widens
        // the run, not an item.
        #expect(tiled.width == float.width)
    }

    @Test("No mark without both sections")
    func noMarkWithOneSection() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2)])
        #expect(overlay.floatMark.isHidden)
        show(overlay, [item(3, floating: true)])
        #expect(overlay.floatMark.isHidden)
    }

    @Test("A float item neither reorders nor takes a drop")
    func floatDoesNotReorder() {
        let overlay = AppBarOverlay()
        var moves: [(Int, Int)] = []
        overlay.onMove = { moves.append(($0, $1)) }
        show(
            overlay,
            [item(1), item(2), item(3, floating: true)]
        )
        let float = overlay.itemViews[2]
        overlay.dragEnded(float)
        #expect(moves.isEmpty)
        // A tiled item dragged past the break lands last in the
        // row, never among the floats.
        let first = overlay.itemViews[0]
        first.frame.origin.x = overlay.itemViews[2].frame.midX
        overlay.dragEnded(first)
        #expect(moves.map(\.0) == [0])
        #expect(moves.map(\.1) == [1])
    }

    @Test("The bar scrolls to a focused float past its end")
    func scrollFollowsFloat() {
        let overlay = AppBarOverlay()
        let items =
            (1...12).map { item(UInt32($0)) }
            + [item(13, floating: true)]
        overlay.show(
            items: items,
            activeIndex: 12,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        let float = overlay.itemViews[12].frame
        let shown = overlay.itemContainer.bounds
            .offsetBy(dx: overlay.scrollOffset, dy: 0)
        #expect(overlay.scrollOffset > 0)
        #expect(shown.contains(float))
    }

    @Test("VoiceOver says the item floats")
    func floatNarration() {
        LocalizationManager.shared.select("en")
        let overlay = AppBarOverlay()
        var titled = item(4, floating: true)
        titled = AppBarOverlay.Item(
            id: titled.id,
            name: "Notes",
            text: "Groceries",
            icon: nil,
            floating: true
        )
        show(overlay, [item(1), item(3, floating: true), titled])
        let labels = overlay.itemViews.map { $0.accessibilityLabel() }
        #expect(
            labels == [
                "App1",
                "App3, floating window",
                "Notes, floating window Groceries",
            ]
        )
    }
}
