import AppKit
import Testing

@testable import KiwiDeskCore

/// An Auto App Bar on the screen stands the Space Bar's front-app
/// segment down on any edge (#3359): beside its handle the Space
/// Bar's share is measured without one. Only a Hidden App Bar
/// leaves the segment the room #761 gives it.
@Suite("Front app beside a resting App handle (#3359)", .serialized)
@MainActor
struct ShelfLandingFrontAppTests {
    private static let window = WindowID(900_103)

    private func core(
        app visibility: ShelfVisibility,
        edge: AppBarEdge = .top
    ) throws -> KiwiCore {
        let screen = try #require(NSScreen.screens.first)
        let display = try #require(screen.kiwiDisplay)
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 900_103,
                    appName: "Front",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        let space = try #require(
            core.state.workspaces.space(of: Self.window)
        )
        core.state.workspaces.setMode(space, .monocle)
        core.state.workspaces.withSpace(space) {
            $0.focused = Self.window
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(edge)
        settings.spaceBarStyle.visibility = .auto
        settings.spaceBarStyle.showFrontApp = true
        settings.monocle.appBar.visibility = visibility
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        #expect(core.execute("space_bar.toggle_reveal", args: []).isSuccess)
        core.updateBars()
        return core
    }

    @Test(
        "a resting App handle stands the front app down",
        .enabled(if: NSScreen.main != nil)
    )
    func handleHoldsTheRoom() throws {
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let resting = try core(app: .auto)
        #expect(!resting.spaceBars.showsTitle(of: Self.window))
        let hidden = try core(app: .hidden)
        #expect(hidden.spaceBars.showsTitle(of: Self.window))
        // One screen-wide answer: an Auto App Bar on another edge.
        let apart = try core(app: .auto, edge: .bottom)
        #expect(!apart.spaceBars.showsTitle(of: Self.window))
        // And a drawn App Bar on another edge, as before.
        let drawn = try core(app: .always, edge: .bottom)
        #expect(!drawn.spaceBars.showsTitle(of: Self.window))
    }
}
