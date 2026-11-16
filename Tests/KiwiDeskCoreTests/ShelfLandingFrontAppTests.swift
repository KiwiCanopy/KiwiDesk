import AppKit
import Testing

@testable import KiwiDeskCore

/// A revealed Space Bar beside a resting App Bar handle draws no
/// front-app segment (#3359): its slot is its share of the pair,
/// measured without one, while beside a Hidden App Bar the segment
/// keeps the room #761 leaves it.
@Suite("Front app beside a resting App handle (#3359)", .serialized)
@MainActor
struct ShelfLandingFrontAppTests {
    private static let window = WindowID(900_103)

    private func core(app visibility: ShelfVisibility) throws -> KiwiCore {
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
        settings.appBarStyle.setEdge(.top)
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
    }
}
