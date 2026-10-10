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

    /// The primary screen's whole frame in AX coordinates — the
    /// one the fixture's editor frame sits on. Never
    /// `NSScreen.main`, which follows keyboard focus to another
    /// screen and leaves the editor off the one under test.
    private var screenFrame: CGRect? {
        NSScreen.screens.first.map {
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
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay,
            let bounds = screenFrame
        else { return nil }
        let core = makeCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.tiler.allScreenFrames = { [bounds] }
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
        // A tiled editor beside the show, so the Scrolling App
        // Bar has an item to paint and its stand-down is visible.
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 2,
                    appName: "Editor",
                    frame: CGRect(x: 100, y: 100, width: 800, height: 600)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = core.state.workspaces.space(of: Self.show)!
        core.state.workspaces.setMode(space, .scrolling)
        core.tiler.settings.scrolling.appBar.enabled = true
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
        #expect(core.placementBounce(Self.show, now: core.wallClock()) == nil)
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
        #expect(!core.appBars.shownStrips.isEmpty)

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

        // And back out: a move off the cover brings the shelf back.
        core.handle(.windowMoved(Self.show, opening))
        #expect(!core.spaceBars.shownStrips.isEmpty)
    }

    @Test("A resize onto the cover re-reads the shelf too")
    func resizeCrossingReReadsTheShelf() throws {
        let screen = try #require(screenFrame)
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let core = try #require(
            makeShelfCore(frame: screen.insetBy(dx: 8, dy: 5))
        )
        core.shelves.frontWindowFrames = { [screen] }
        core.updateBars()
        #expect(!core.spaceBars.shownStrips.isEmpty)

        // A resize to the cover retiles nothing: the fit leaves a
        // presenting float alone, so only the crossing re-reads.
        core.handle(.windowResized(Self.show, screen))

        #expect(core.spaceBars.shownStrips.isEmpty)
    }

    /// The Desktop cue (#2142) stands down where the shelf does:
    /// a show in FRONT keeps the plate off its screen, and the
    /// debt still settles.
    @Test("A presentation in front keeps the Desktop cue away")
    func presentationKeepsTheDesktopCueAway() throws {
        let screen = try #require(screenFrame)
        defer {
            NativeSpaces.currentSpaceIsUserOverride = nil
            resetAuthorityOverrides()
        }
        let core = try #require(makeShelfCore(frame: screen))
        NativeSpaces.displayUUIDOverride = { _ in "UUID-A" }
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.spacesOverride = [10, 11].map {
            NativeSpace(id: $0, displayUUID: "UUID-A", isCurrent: $0 == 11)
        }
        var shown = 0
        core.desktopCue.onCue = { _ in shown += 1 }
        func owe() {
            core.desktopCue.owed = .init(
                displayUUID: "UUID-A",
                space: 11,
                at: core.wallClock()
            )
        }
        let editor = CGRect(x: 100, y: 100, width: 800, height: 600)
        // Control: the editor in front, so the plate shows.
        core.shelves.frontWindowFrames = { [editor, screen] }
        owe()
        core.payDesktopCue(
            in: NativeSpaces.desktopSnapshot(),
            loadedProfile: nil
        )
        #expect(shown == 1)
        core.shelves.frontWindowFrames = { [screen, editor] }
        owe()
        core.payDesktopCue(
            in: NativeSpaces.desktopSnapshot(),
            loadedProfile: nil
        )
        #expect(shown == 1)
        #expect(core.desktopCue.owed == nil)
    }
}
