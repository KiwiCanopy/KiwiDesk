import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// **A test core draws no shelf panel unless its suite asks**
/// (#1894): a panel is a real window on the developer's screen,
/// and a core outlives its test while a task still holds it, so
/// one run put ~750 panels up. Counted on the core's own manager:
/// suites run in parallel, so a process-wide count after a suite
/// would read its neighbours'.
@Suite("Shelf panels in test cores (#1894)", .serialized)
@MainActor
struct ShelfPanelInertTests {
    private static let window = WindowID(1)

    /// A default twin with one window and both bars on, its bars
    /// rendered through `updateBars`; `draws` overrides the pin.
    private func makeCore(draws: Bool? = nil) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        if let draws { core.shelves.drawsPanels = draws }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 1,
                    appName: "InertApp",
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
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "A default twin renders its bars and holds no panel",
        .enabled(if: NSScreen.main != nil)
    )
    func defaultTwinHoldsNoPanel() throws {
        let (core, display) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The bars did render: the count below is not vacuous.
        #expect(core.spaceBars.shownOverlay(on: display) != nil)
        #expect(core.appBars.shownOverlay(on: display) != nil)
        #expect(core.shelves.panelCount == 0)
        #expect(core.shelves.overlayForTesting(display) == nil)
    }

    @Test(
        "A suite that asks gets the shelf's panel",
        .enabled(if: NSScreen.main != nil)
    )
    func optInDrawsThePanel() throws {
        let (core, display) = try #require(makeCore(draws: true))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(core.shelves.panelCount == 1)
        let shelf = try #require(core.shelves.overlayForTesting(display))
        _ = shelf.hide(animated: false)
    }
}
