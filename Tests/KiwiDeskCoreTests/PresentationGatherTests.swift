import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A space entering floating mode gathers every member outside
/// the float region into the quit grid (#1177) — except one
/// presenting over its whole screen, which stays where its app
/// put it (#1787). A show's frame is outside the region by
/// construction (the region excludes the menu bar), so without
/// the skip the entry re-grids the slide show.
@Suite("A presentation is not gathered (#1787)", .serialized)
@MainActor
struct PresentationGatherTests {
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1920,
        height: 1080
    )
    private static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )
    private static let show = WindowID(1)
    private static let scrolledOut = WindowID(2)
    private static let space = SpaceID("1")

    private func makeCore(pinsScreen: Bool) -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.bounds }
        core.tiler.allScreenBounds = { [Self.bounds] }
        core.shelves.screenFrames = { pinsScreen ? [Self.screen] : [] }
        core.tiler.settings.animations.onRelayout = false
        core.tiler.settings.spaceBarStyle.enabled = false
        core.tiler.settings.borderStyle.enabled = false
        core.state.apply(.displaysChanged([display]))
        let frames: [(WindowID, CGRect)] = [
            (Self.show, Self.screen),
            (
                Self.scrolledOut,
                CGRect(x: 2100, y: 100, width: 800, height: 600)
            ),
        ]
        for (id, frame) in frames {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 1,
                        appName: "App",
                        frame: frame
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.setMode(Self.space, .scrolling)
        core.settleDrawnSpaceModes()
        return core
    }

    @Test(
        "Entering floating grids the rest and leaves the show",
        .enabled(if: NSScreen.main != nil)
    )
    func entryLeavesTheShow() throws {
        // The negative twin first: with no screen for the show to
        // cover, the same entry DOES grid it, so the assertion
        // below cannot pass on a gather that never ran.
        let control = try #require(makeCore(pinsScreen: false))
        control.setSpaceMode(Self.space, .floating)
        control.retile(pass: .apply)
        _ = try #require(control.tiler.stashOriginal(Self.show))

        let core = try #require(makeCore(pinsScreen: true))
        core.setSpaceMode(Self.space, .floating)
        core.retile(pass: .apply)

        #expect(core.tiler.stashOriginal(Self.scrolledOut) != nil)
        #expect(core.tiler.stashOriginal(Self.show) == nil)
    }
}
