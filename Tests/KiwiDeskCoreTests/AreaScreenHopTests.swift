import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `focus_display` and `move_to_display` step between the areas of
/// a split screen as between screens (#3517 ruling 18). Needs a host
/// screen to hang the pinned frames on, so a screenless runner
/// skips.
@Suite(
    "Area screen hop",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct AreaScreenHopTests {
    private static let whole = CGRect(x: 0, y: 0, width: 3440, height: 1440)

    private func core() -> (KiwiCore, [PlacementID])? {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID,
            let split = ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.whole }
        core.tiler.screenFrameAX = { _ in Self.whole }
        core.tiler.displayFrames = { [(id: id, frame: Self.whole)] }
        let display = Display(id: id, name: "Wide", frame: Self.whole)
        core.state.workspaces.setAreaSplits([display.fingerprint: split])
        core.state.workspaces.upsertDisplay(display)
        let areas = core.state.workspaces.placements(of: id).map(\.id)
        core.state.workspaces.assign(SpaceID("1"), to: areas[0])
        core.state.workspaces.assign(SpaceID("2"), to: areas[1])
        core.state.workspaces.activate(SpaceID("1"))
        return (core, areas)
    }

    @Test func placementFramesAreTheAreas() {
        guard let (core, areas) = core() else { return }
        let frames = core.placementFrames()
        #expect(frames.map(\.id) == areas)
        #expect(frames.map(\.frame.minX) == [0, 1720])
    }

    @Test func focusDisplayStepsToTheNextArea() {
        guard let (core, _) = core() else { return }
        #expect(core.screenAhead(.right) != nil)
        let reply = core.execute(
            "focus_display",
            args: [.string("right")]
        )
        #expect(reply.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.screenAhead(.right) == nil)
    }
}
