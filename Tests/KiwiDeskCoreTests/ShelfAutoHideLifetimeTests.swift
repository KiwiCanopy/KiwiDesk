import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The kept shelf, the surfaces that hold a reveal, and the
/// reveal's landing (#761), through the real managers.
@Suite("Shelf auto-hide lifetime (#761)", .serialized)
@MainActor
struct ShelfAutoHideLifetimeTests {
    private func makeCore() -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "KeptApp",
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
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, display.id)
    }

    @Test(
        "A retracted hiding shelf is kept; one that stops hiding goes",
        .enabled(if: NSScreen.main != nil)
    )
    func keptBetweenReveals() throws {
        let (core, display) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = core.execute("space_bar.toggle_reveal", args: [])
        let shown = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        _ = core.execute("space_bar.toggle_reveal", args: [])
        #expect(core.shelves.overlayForTesting(display, edge: .top) === shown)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.updateBars()
        #expect(core.shelves.overlayForTesting(display, edge: .top) == nil)
    }

    @Test(
        "Only the shelf a menu opened on is held by it",
        .enabled(if: NSScreen.main != nil)
    )
    func menuHoldsItsShelf() throws {
        let (core, display) = try #require(makeCore())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        _ = core.execute("space_bar.toggle_reveal", args: [])
        let key = ShelfManager.Key(display: display, edge: .top)
        let panel = try #require(
            core.shelves.overlayForTesting(display, edge: .top)?.panel
        )
        let peek = core.shelves.peek
        peek.menuTrackingOverride = true
        #expect(!core.shelves.surfaceHolds(key))
        peek.noteMenuAnchor(panel)
        #expect(core.shelves.surfaceHolds(key))
        peek.menuTrackingOverride = false
        #expect(!core.shelves.surfaceHolds(key))
    }

    @Test("A stale landing never ends a newer reveal's motion")
    func staleLandingKeepsTheNewerReveal() {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let overlay = ShelfOverlay()
        var landings: [() -> Void] = []
        overlay.afterReveal = { _, body in landings.append(body) }
        overlay.afterCommit = { $0() }
        overlay.content.frame = CGRect(x: 0, y: 0, width: 400, height: 40)
        let motion = {
            overlay.content.layer?.animation(forKey: "kiwi.reveal")
        }
        overlay.revealIn(ordering: true)
        _ = overlay.retractOut()
        overlay.revealIn()
        // The first slide-in's landing arrives during the third.
        landings[0]()
        #expect(motion() != nil)
        landings[2]()
        #expect(motion() == nil)
    }
}
