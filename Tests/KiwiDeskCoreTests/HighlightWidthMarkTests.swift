import AppKit
import Testing

@testable import KiwiDeskCore

/// The hidden shelf's hover rim takes the bars' indicator weight
/// and sheen (#761, bars.md ▸ an indicator's weight), through the
/// real `updateBars()`: the width follows `highlight_width` up to
/// the plate's growth, and the rim view draws what the spec says.
@Suite("Hidden mark rim weight (#761)", .serialized)
@MainActor
struct HighlightWidthMarkTests {
    @Test("The rim follows the highlight width, capped at the growth")
    func rimWidthFollowsTheShelf() {
        var shelf = KiwiShelf()
        shelf.highlightWidth = 1
        #expect(ShelfIndicatorSpec.rimWidth(for: shelf) == 1)
        shelf.highlightWidth = 6
        #expect(
            ShelfIndicatorSpec.rimWidth(for: shelf)
                == ShelfIndicatorSpec.hoverGrowth
        )
    }

    @Test(
        "updateBars hands the mark the shelf's width and sheen",
        .enabled(if: NSScreen.main != nil)
    )
    func markReadsTheShelf() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "RimApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.visibility = .always
        settings.monocle.appBar.visibility = .hidden
        settings.scrolling.appBar.visibility = .hidden
        settings.barEdge = .top
        settings.spaceBarStyle.visibility = .auto
        settings.kiwishelf.highlightWidth = 2
        settings.borderStyle.sheen = 0.5
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        let key = ShelfManager.Key(display: display.id, edge: .top)
        let view = try #require(
            core.shelves.indicators.indicatorForTesting(
                .init(shelf: key, bar: .space)
            )?.view
        )
        let spec = try #require(view.spec)
        #expect(spec.rimWidth == 2)
        #expect(spec.sheen == 0.5)
        #expect(view.rim.ink?.width == 2)
        #expect(view.rim.ink?.sheen == 0.5)
    }
}
