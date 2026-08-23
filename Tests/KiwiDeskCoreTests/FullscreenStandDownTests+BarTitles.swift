import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

// The #670 stand-down as the two bar-title paths see it. Split
// from `FullscreenStandDownTests.swift` at the §2.1 hard ceiling,
// and deliberately an EXTENSION rather than a second suite: the
// `isUser` DEBUG overrides these tests pin are process-global, so
// a second suite would race the first under parallel testing.
// Same suite, same serialization.

private let barWindow = WindowID(1)

private func barTitleWindow() -> ManagedWindow {
    ManagedWindow(
        id: barWindow,
        pid: pid_t(barWindow.raw),
        appName: "App\(barWindow.raw)"
    )
}

@MainActor
extension FullscreenStandDownTests {
    /// The title-refresh gate stands down with the bars — and
    /// does so BECAUSE they did, not by re-deciding it.
    ///
    /// This is where the gate and the drivers meet: `updateAppBar`
    /// runs for real under each verdict, and the gate is then
    /// asked what the painted record says
    /// (`AppBarManager.showsTitle(of:)`). The predecessor asked
    /// the gate alone, against its own copy of the rule — which
    /// is how a three-rule copy of a five-gate policy passed here
    /// while disagreeing with the Space Bar driver (review
    /// 2026-08-20). A copy that cannot exist cannot drift.
    @Test("A fullscreen space schedules no title refresh")
    func titleRefreshStandsDown() {
        let core = makeCore()
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(.windowCreated(barTitleWindow()))
        core.resolveSpaceDisplays(mainID: display.id)
        let spaceID = core.state.workspaces.space(of: barWindow)!
        _ = core.execute(
            "set_mode",
            args: [.string(spaceID.raw), .string("monocle")]
        )
        core.tiler.settings.appBarStyle.content = .iconAndTitle
        core.tiler.settings.appBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.showFrontApp = false
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }

        // A user desktop schedules, so the negative below cannot
        // pass by the fixture simply never qualifying.
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateAppBar()
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(barWindow)
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)

        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        core.updateAppBar()
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(barWindow)
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }

    /// The Space Bar driver's half of the same seam — and the
    /// only place the `frontWindow` hop is observed at all.
    ///
    /// `SpaceBarDriverTests` asserts what `frontApp` RETURNS and
    /// the gate's own suite paints its bar by hand, so dropping
    /// `frontWindow` on the way into `SpaceBarManager.Bar` left
    /// both green while the Space Bar half of the refresh died
    /// (mutation, 2026-08-20).
    ///
    /// It lives here rather than beside the gate's suite because
    /// driving the real `updateSpaceBar` reaches
    /// `currentSpaceIsUser`, and a test that pins that override
    /// belongs to this one serialized suite — unpinned, it reds
    /// on a dev machine whenever a fullscreen window is front.
    @Test("The Space Bar driver arms the gate through its bar")
    func spaceBarTitleRefreshStandsDown() {
        let core = makeCore()
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(.windowCreated(barTitleWindow()))
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.apply(.windowFocused(barWindow))
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.spaceBarStyle.showFrontApp = true
        // Since #937 `.icon` no longer stands the App Bar
        // down; it stays silent here only because no App Bar
        // is ever painted in this fixture (`updateAppBar` is
        // not called), so the arm below is the Space Bar's.
        core.tiler.settings.appBarStyle.content = .icon
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }

        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateSpaceBar()
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(barWindow)
        #expect(core.deferred.task(for: .barTitleRefresh) != nil)

        // ...about THAT window, not any window.
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(WindowID(999))
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)

        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        core.updateSpaceBar()
        core.deferred.cancel(.barTitleRefresh)
        core.handleTitleChangedForBars(barWindow)
        #expect(core.deferred.task(for: .barTitleRefresh) == nil)
    }
}
