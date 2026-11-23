import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space switch on a split screen slides its target's area alone
/// (#3517 ruling 8): the slide leaves the Space that area shows,
/// never the screen's lead area's, and plays on that area's part of
/// the screen.
@Suite("Area Space slide (#3517)")
@MainActor
struct AreaSpaceSlideTests {
    /// One screen split side by side at `size`: Space 1 left,
    /// Spaces 2 and 3 right, the right area showing 2.
    private func makeCore(
        size: CGSize = CGSize(width: 3440, height: 1440)
    ) -> (KiwiCore, [PlacementID]) {
        let core = makeTestCore()
        let display = Display(
            id: DisplayID(7),
            name: "Wide",
            frame: CGRect(origin: .zero, size: size)
        )
        let split = ScreenSplit.whole(
            width: Int(size.width),
            height: Int(size.height)
        ).splitting(0, .sideBySide)
        core.state.workspaces.setAreaSplits(
            split.map { [display.fingerprint: $0] } ?? [:]
        )
        core.state.workspaces.upsertDisplay(display)
        let areas = core.state.workspaces.placements(of: display.id)
            .map(\.id)
        let homes = [(1, 0), (2, 1), (3, 1)]
        for (space, area) in homes where areas.count > area {
            core.state.workspaces.ensureSpace(SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: areas[area])
        }
        core.state.workspaces.activate(SpaceID(1))
        if areas.count > 1 {
            core.state.workspaces.show(SpaceID(2), on: areas[1])
        }
        return (core, areas)
    }

    @Test("the slide leaves the Space its own area shows")
    func leavesItsOwnArea() throws {
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let intent = try #require(core.spaceSlideIntent(to: SpaceID(3)))
        #expect(intent.leaving == SpaceID(2))
        #expect(intent.display == DisplayID(7))
    }

    @Test("a Space its area already shows slides nothing")
    func shownSpaceSlidesNothing() throws {
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        #expect(core.spaceSlideIntent(to: SpaceID(2)) == nil)
    }

    @Test(
        "the page is the target's area",
        .enabled(if: NSScreen.main != nil)
    )
    func pageIsTheArea() throws {
        let screen = try #require(ScreenList.all.first)
        let (core, areas) = makeCore(size: screen.frame.size)
        try #require(areas.count == 2)
        let whole = GeometryUtils.flip(
            screen.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        let right = core.slidePage(of: SpaceID(3), on: screen)
        let left = core.slidePage(of: SpaceID(1), on: screen)
        #expect(right.maxX == whole.maxX)
        #expect(left.minX == whole.minX)
        #expect(left.width + right.width == whole.width)
        #expect(right.height == whole.height)
    }
}
