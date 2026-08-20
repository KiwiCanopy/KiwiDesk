import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// That the debounced pass DOES something.
///
/// `BarTitleRefreshTests.burstDebounces` asserts on task
/// identity, which an empty body satisfies — emptying
/// `runBarTitleRefresh()` was inert across every test in the new
/// suites (guard-prover, 2026-08-19). The only honest observation
/// is the rendered item text, which is the one thing the refresh
/// exists to change.
///
/// Its own file because its fixture differs on purpose: this one
/// goes through the DRIVER, so no display is assigned and
/// `updateAppBar` takes its documented cold-start fallback to the
/// main screen — a real bar without a `DisplayID` that happens to
/// match this host's. The gate's own suite paints through the
/// manager instead, and the two meet in
/// `FullscreenStandDownTests.titleRefreshStandsDown`, which
/// proves the gate follows what the driver painted.
@Suite(
    "Bar title refresh output",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct BarTitleRefreshOutputTests {
    private func seededOnMainScreen() -> KiwiCore {
        let core = makeBarCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        core.tiler.settings.monocle.appBar.enabled = true
        core.tiler.settings.appBarStyle.content = .iconAndTitle
        core.tiler.settings.appBarStyle.edge = .top
        core.state.apply(
            .windowCreated(titledWindow(1, title: "Downloads"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    @Test("The refresh re-renders the bar with the new title")
    func refreshRedrawsTheItem() throws {
        let core = seededOnMainScreen()
        core.updateAppBar()
        // `#require`, not `if let`: a fixture that built no bar
        // would make every assertion below pass vacuously, which
        // is the failure this whole suite exists to rule out.
        let before = try #require(
            core.appBars.shownBarsForTesting.first?.items.first
        )
        #expect(before.text == "Downloads")

        core.state.apply(
            .windowTitleChanged(WindowID(1), "Projects")
        )
        core.runBarTitleRefresh()

        let after = try #require(
            core.appBars.shownBarsForTesting.first?.items.first
        )
        #expect(after.text == "Projects")
    }

    /// The Space Bar driver RECORDS which window its front
    /// segment is about, so the gate can read it back.
    ///
    /// Its own test because nothing else observes that hop:
    /// `SpaceBarDriverTests` asserts what `frontApp` returns, and
    /// the gate's suite paints the bar by hand — dropping
    /// `frontWindow` on the way into `SpaceBarManager.Bar` left
    /// both green while the Space Bar half of the refresh died
    /// (mutation-proved, 2026-08-20). Needs the host's real
    /// display: `updateSpaceBar` has no cold-start fallback, by
    /// design.
    @Test("The Space Bar driver arms the gate through its bar")
    func spaceBarDriverArmsTheGate() throws {
        let core = makeBarCore()
        let display = try #require(NSScreen.main?.kiwiDisplay)
        core.state.apply(.displaysChanged([display]))
        core.state.workspaces.assign(SpaceID("1"), to: display.id)
        core.state.workspaces.activate("1")
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.showFrontApp = true
        core.tiler.settings.monocle.appBar.enabled = false
        core.tiler.settings.appBarStyle.content = .icon
        core.state.apply(
            .windowCreated(titledWindow(1, title: "Downloads"))
        )
        core.state.apply(.windowFocused(WindowID(1)))
        core.updateSpaceBar()
        core.deferred.cancel(.barTitleRefresh)

        core.handleTitleChangedForBars(WindowID(1))
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)

        // ...and it is about THAT window, not any window.
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(WindowID(999))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }
}
