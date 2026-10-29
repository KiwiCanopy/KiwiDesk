import AppKit
import Testing

@testable import KiwiDeskCore

/// Where a bar's show/hide refusal stands (#2567 ▸ owner): beside
/// the shelf carrying that bar, else at that bar's own edge of the
/// screen — never on a window and never beside the other bar's
/// shelf, so an empty Space with no focus still shows it.
@Suite("A bar's refusal pill sits at the bar (#2567)", .serialized)
@MainActor
struct ShelfRefusalPlaceTests {
    @Test(
        "With no shelf of its own, the pill takes the bar's edge",
        .enabled(if: NSScreen.main != nil)
    )
    func barEdgeWithoutShelf() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.currentSpace(on: display.id)
        )
        core.state.workspaces.setMode(space, .monocle)
        var settings = core.tiler.settings
        // The Space Bar shown on top, the App Bar's edge the bottom.
        settings.spaceBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .always
        settings.appBarStyle.setEdge(.bottom)
        settings.monocle.appBar.visibility = .auto
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        #expect(core.focusedWindowID == nil)
        let place = try #require(core.refusalPlace(of: .app, on: display.id))
        #expect(place.edge == .bottom)
        #expect(place.strip.height == 0)
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        #expect(place.strip.minY == visible.maxY)
        // The Space Bar's refusal stands beside its own shown shelf.
        let spaceBar = try #require(
            core.refusalPlace(of: .space, on: display.id)
        )
        #expect(spaceBar.edge == .top)
        #expect(spaceBar.strip.height > 0)
    }

    /// The empty pill asks the bar's own content: empty → the pill;
    /// a window → none.
    @Test(
        "The empty refusal asks the bar's content",
        .enabled(if: NSScreen.main != nil)
    )
    func emptyRefusalAsksTheContent() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.currentSpace(on: display.id)
        )
        core.state.workspaces.setMode(space, .monocle)
        #expect(
            core.emptyRefusal(.app, on: display.id) == .nothingToShow(.app)
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(900_301),
                    pid: 900_301,
                    appName: "Content",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        #expect(core.emptyRefusal(.app, on: display.id) == nil)
    }

    /// A shelf stood down for what is in front is why nothing shows,
    /// whatever the bar's setting says (#2775): the command answers
    /// the stand-down before the Space Bar's `always`.
    @Test(
        "A stood-down shelf refuses before the bar's setting",
        .enabled(if: NSScreen.main != nil)
    )
    func standDownRefusesFirst() throws {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.resolveSpaceDisplays(mainID: display.id)
        var settings = core.tiler.settings
        settings.spaceBarStyle.visibility = .always
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        #expect(
            core.shelfRevealCommand(.space).error
                == "the Space Bar is set to always"
        )
        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        #expect(
            core.shelfRevealCommand(.space).error
                == "the Space Bar stands down for what is in front"
        )
    }
}
