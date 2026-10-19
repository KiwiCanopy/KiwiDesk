import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Two `auto` bars on one edge (#761, owner 2026-10-19): one mark
/// each, as one row in the middle of the edge, each with its own
/// band, the two meeting edge to edge at the middle. The mouse
/// opens one bar at a time — a sibling's mark stands aside and its
/// band goes while a bar shows — and the keyboard merges both.
@Suite("Shelf reveal pair (#761)", .serialized)
@MainActor
struct ShelfRevealPairTests {
    private static let window = WindowID(900_762)

    /// A core on the primary screen with one window in a monocle
    /// Space, both bars `auto` on the top edge. Nil where the host
    /// has no screen to paint on.
    private func makeCore() -> (KiwiCore, ShelfManager.Key)? {
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
                    pid: 900_762,
                    appName: "PairApp",
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
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        settings.kiwishelf.alignment = .center
        settings.kiwishelf.order = .spacesFirst
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, ShelfManager.Key(display: display.id, edge: .top))
    }

    private func spec(
        _ core: KiwiCore,
        _ shelf: ShelfManager.Key,
        _ bar: ShelfBar
    ) -> ShelfIndicatorSpec? {
        core.shelves.indicators.indicatorForTesting(
            .init(shelf: shelf, bar: bar)
        )?.view.spec
    }

    private func target(
        _ core: KiwiCore,
        _ shelf: ShelfManager.Key,
        _ bar: ShelfBar
    ) -> ShelfRevealer.Target? {
        core.shelves.reveal.targets[.init(shelf: shelf, bar: bar)]
    }

    @Test(
        "two marks sit as one row, their bands meeting at the middle",
        .enabled(if: NSScreen.main != nil)
    )
    func pairMeetsAtTheMiddle() throws {
        let (core, shelf) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let space = try #require(spec(core, shelf, .space))
        let app = try #require(spec(core, shelf, .app))
        guard case .dots = space.mark, case .line = app.mark else {
            Issue.record("the Space Bar draws dots, the App Bar a line")
            return
        }
        let length = ShelfMarkPlacement.bandLength
        #expect(abs(app.frame.midX - space.frame.midX - length) < 0.5)
        let spaceBand = try #require(target(core, shelf, .space)?.band)
        let appBand = try #require(target(core, shelf, .app)?.band)
        #expect(spaceBand.width == length)
        #expect(appBand.width == length)
        #expect(spaceBand.maxX == appBand.minX)
        #expect(!spaceBand.intersects(appBand))
        let middle = (space.frame.midX + app.frame.midX) / 2
        #expect(abs(spaceBand.maxX - middle) < 0.5)
    }

    @Test(
        "a shown bar's sibling stands aside, and its shortcut merges it",
        .enabled(if: NSScreen.main != nil)
    )
    func oneBarPerMouseKeyboardMerges() throws {
        let (core, shelf) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        // The App Bar's mark stands aside and its band goes.
        let app = try #require(spec(core, shelf, .app))
        #expect(app.yields)
        #expect(!app.shown)
        #expect(target(core, shelf, .app)?.hovers == false)
        #expect(core.appBars.shownStrips.isEmpty)
        // Its shortcut still shows it, beside the Space Bar.
        #expect(core.execute("app_bar.toggle_reveal", args: []).isSuccess)
        #expect(!core.spaceBars.shownStrips.isEmpty)
        #expect(!core.appBars.shownStrips.isEmpty)
        #expect(spec(core, shelf, .app)?.yields == false)
        #expect(target(core, shelf, .app)?.hovers == true)
    }

    @Test(
        "a press on a mark shows only its own bar",
        .enabled(if: NSScreen.main != nil)
    )
    func pressShowsItsBar() throws {
        let (core, shelf) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.shelves.indicators.onPress(.init(shelf: shelf, bar: .app))
        #expect(
            core.shelves.reveal.reveal(of: .init(shelf: shelf, bar: .app))
                .isShown
        )
        #expect(
            !core.shelves.reveal.reveal(of: .init(shelf: shelf, bar: .space))
                .isShown
        )
    }
}
