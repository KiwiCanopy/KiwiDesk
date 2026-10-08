import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Split bars through the real drivers (#1731): a shelf panel per
/// edge while the bars sit apart, each carrying its own bar, and
/// one again once they share an edge.
@Suite("Shelf split drivers (#1731)", .serialized)
@MainActor
struct ShelfSplitDriverTests {
    private static let window = WindowID(1)

    /// A core on the primary screen holding one window in a
    /// scrolling space, both bars on, the Space Bar on `space` and
    /// the App Bar on `app`. Nil where the host has no screen.
    private func makeCore(
        space: AppBarEdge,
        app: AppBarEdge
    ) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.shelves.drawsPanels = true
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "SplitApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400),
                    isFloating: false
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let id = core.state.workspaces.space(of: Self.window)!
        core.state.workspaces.setMode(id, .scrolling)
        var settings = core.tiler.settings
        settings.spaceBarStyle.enabled = true
        settings.scrolling.appBar.enabled = true
        settings.spaceBarStyle.edge = space
        settings.appBarStyle.edge = app
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "Split bars draw a shelf on each edge",
        .enabled(if: NSScreen.main != nil)
    )
    func splitDrawsTwoShelves() throws {
        let (core, display) = try #require(
            makeCore(space: .top, app: .bottom)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let top = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        let bottom = try #require(
            core.shelves.overlayForTesting(display, edge: .bottom)
        )
        #expect(top !== bottom)
        #expect(top.isVisible && bottom.isVisible)
        let space = try #require(core.spaceBars.shownStrips.first)
        let app = try #require(core.appBars.shownStrips.first)
        #expect(space.edge == .top)
        #expect(app.edge == .bottom)
        #expect(app.strip.minY > space.strip.maxY)
        // Each shelf carries only its own bar's section.
        #expect(
            core.spaceBars.shownOverlay(on: display)?.root.superview
                === top.stripView
        )
        #expect(
            core.appBars.shownOverlay(on: display)?.root.superview
                === bottom.stripView
        )
        // Apart, the Space Bar keeps its front-app stand-down only
        // while an App Bar shows on the display, wherever it sits.
        #expect(!core.spaceBars.showsTitle(of: Self.window))
    }

    @Test(
        "Re-fusing retires the second shelf",
        .enabled(if: NSScreen.main != nil)
    )
    func refuseRetiresTheSecondShelf() async throws {
        let (core, display) = try #require(
            makeCore(space: .top, app: .bottom)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The band's floor: `updateBars()` derives the glide from
        // the setting, so a fixture pins what the path reads.
        core.tiler.settings.animations.shelfDurationMS = 500
        core.tiler.settings.appBarStyle.edge = .top
        core.updateBars()
        // The second shelf fades out and is retired once its fade
        // lands (#1838).
        for _ in 0..<150
        where core.shelves.overlayForTesting(display, edge: .bottom) != nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(core.shelves.overlayForTesting(display, edge: .bottom) == nil)
        let top = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        #expect(
            core.appBars.shownOverlay(on: display)?.root.superview
                === top.stripView
        )
        #expect(
            core.spaceBars.shownOverlay(on: display)?.root.superview
                === top.stripView
        )
    }

    /// Splitting a fused shelf moves the App Bar's section to the
    /// new shelf while the old one's leave is still landing; that
    /// landing must not pull it back out of the new strip (#1838).
    @Test(
        "Splitting keeps the moved section on its new shelf",
        .enabled(if: NSScreen.main != nil)
    )
    func splitKeepsTheMovedSection() async throws {
        let (core, display) = try #require(
            makeCore(space: .top, app: .top)
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.settings.animations.shelfDurationMS = 500
        core.tiler.settings.appBarStyle.edge = .bottom
        core.updateBars()
        let bottom = try #require(
            core.shelves.overlayForTesting(display, edge: .bottom)
        )
        let app = try #require(core.appBars.shownOverlay(on: display))
        #expect(app.root.superview === bottom.stripView)
        // The old shelf's landing is observable only by its own
        // write: the leaving set emptying.
        let top = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        for _ in 0..<150 where !top.leavingViews.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(top.leavingViews.isEmpty)
        #expect(app.root.superview === bottom.stripView)
    }
}
