import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window covering its whole screen is presenting (#1787) —
/// PowerPoint's slide show. The float fit leaves it where its
/// app put it, and a screen showing one in FRONT stands the
/// shelf down as a native-fullscreen Space does. An extension of
/// this suite, not a second one: every case holds the
/// process-global `currentSpaceIsUserOverride` (see the suite's
/// header).
extension FullscreenStandDownTests {
    private static let show = WindowID(1)

    /// The main screen's whole frame in AX coordinates.
    private var screenFrame: CGRect? {
        NSScreen.main.map {
            GeometryUtils.flip(
                $0.frame,
                primaryHeight: GeometryUtils.primaryHeight
            )
        }
    }

    /// A core showing the Space Bar over one Scrolling space
    /// that holds one flag-floating window at `frame` — the
    /// device shape. Nil where the host has no screen.
    private func makeShelfCore(frame: CGRect) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.show,
                    pid: 1,
                    appName: "Slides",
                    frame: frame,
                    isFloating: true
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.show)!
        core.state.workspaces.setMode(space, .scrolling)
        core.tiler.settings.spaceBarStyle.enabled = true
        core.tiler.settings.barEdge = .top
        core.tiler.settings.kiwishelf.thickness = 40
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        core.tiler.placements.forgetAll()
        return core
    }

    @Test("The float fit neither moves nor stamps a covering float")
    func fitLeavesACoveringFloat() throws {
        let screen = try #require(screenFrame)
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // The negative twin first: one edge short of covering,
        // the same window IS fitted and stamped, so the
        // assertions below cannot pass on an inert fixture.
        var short = screen
        short.size.height -= 100
        let control = try #require(makeShelfCore(frame: short))
        _ = try #require(control.spaceBars.shownStrips.first)
        control.clampFloatsClearOfBars()
        _ = try #require(control.tiler.recentInstantTarget(Self.show))
        _ = try #require(control.tiler.placements.recent(Self.show))

        // PowerPoint's own ask: 1 pt past every edge. The stamp
        // is what read the show's first focus as a bounce.
        let core = try #require(
            makeShelfCore(frame: screen.insetBy(dx: -1, dy: -1))
        )
        core.clampFloatsClearOfBars()

        #expect(core.tiler.recentInstantTarget(Self.show) == nil)
        #expect(core.tiler.placements.recent(Self.show) == nil)
        #expect(core.placementBounce(Self.show, now: Date()) == nil)
    }

    @Test("A presentation in FRONT stands the shelf down")
    func presentationInFrontStandsShelfDown() throws {
        let screen = try #require(screenFrame)
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeShelfCore(frame: screen))
        // Another window in front of the show — the presenter
        // view, or the editor after a cmd-tab — keeps the shelf.
        let editor = CGRect(x: 100, y: 100, width: 800, height: 600)
        core.shelves.frontWindowFrames = { [editor, screen] }
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)

        core.shelves.frontWindowFrames = { [screen, editor] }
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
        #expect(core.appBars.shownStrips.isEmpty)
    }

    @Test("A neighbour screen's show overscanning in stays out")
    func neighbourOverscanIsNotInFront() throws {
        let screen = try #require(screenFrame)
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(makeShelfCore(frame: screen))
        // The device's two-screen shape: the presenter view on
        // the neighbour screen overscans 1 pt into this one and
        // is front-most, while this screen's show sits behind it.
        var presenter = screen
        presenter.origin.x = screen.minX - screen.width + 1
        core.shelves.frontWindowFrames = { [presenter, screen] }
        core.updateBars()
        #expect(core.spaceBars.shownStrips.isEmpty)
    }

    @Test("A show animating open re-reads the shelf as it covers")
    func coverCrossingReReadsTheShelf() throws {
        let screen = try #require(screenFrame)
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        // Where the focus report found PowerPoint's show on the
        // device: mid-animation, short of every edge.
        let opening = screen.insetBy(dx: 8, dy: 5)
        let core = try #require(makeShelfCore(frame: opening))
        core.shelves.frontWindowFrames = { [screen] }
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)

        // A move retiles nothing, so only the crossing check can
        // retire the shelf here.
        core.handle(.windowMoved(Self.show, screen))

        #expect(core.spaceBars.shownStrips.isEmpty)
    }
}
