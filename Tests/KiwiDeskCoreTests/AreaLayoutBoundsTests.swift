import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space in an area lays out in that area (#3517 ruling 8): the
/// area's rect intersected with the screen's visible frame, so only
/// the area touching the menu bar takes its inset; parking stays the
/// whole screen's (ruling 6); an inner edge reads as a neighbour but
/// never moves the park (ruling 31). Needs a host screen to hang the
/// pinned bounds on, so a screenless runner skips.
@Suite("Area layout bounds", .serialized)
@MainActor
struct AreaLayoutBoundsTests {
    private static let whole = CGRect(x: 0, y: 0, width: 3440, height: 1440)
    private static let visible = CGRect(
        x: 0,
        y: 25,
        width: 3440,
        height: 1415
    )

    private func core(
        _ edit: (ScreenSplit) -> ScreenSplit?
    ) -> (KiwiCore, NSScreen, [PlacementID])? {
        guard let screen = ScreenList.all.first,
            let id = screen.kiwiDisplayID,
            let split = edit(ScreenSplit.whole(width: 3440, height: 1440))
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in Self.visible }
        core.tiler.screenFrameAX = { _ in Self.whole }
        let display = Display(
            id: id,
            name: "Wide",
            frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
        )
        core.state.workspaces.setAreaSplits([display.fingerprint: split])
        core.state.workspaces.upsertDisplay(display)
        let areas = core.state.workspaces.placements(of: id).map(\.id)
        for (i, area) in areas.enumerated() {
            core.state.workspaces.assign(SpaceID(i + 1), to: area)
        }
        return (core, screen, areas)
    }

    @Test func sideBySideAreasLayOutInTheirRects() {
        guard
            let (core, screen, _) = core({
                $0.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
            })
        else { return }
        let middle = core.tiler.visibleBounds(screen, for: SpaceID(2))
        #expect(middle == CGRect(x: 1720, y: 25, width: 860, height: 1415))
        let right = core.tiler.visibleBounds(screen, for: SpaceID(3))
        #expect(right.minX == 2580)
        #expect(right.maxX == 3440)
    }

    @Test func onlyTheTopAreaTakesTheMenuBar() {
        guard let (core, screen, _) = core({ $0.splitting(0, .stacked) })
        else { return }
        let top = core.tiler.visibleBounds(screen, for: SpaceID(1))
        let bottom = core.tiler.visibleBounds(screen, for: SpaceID(2))
        #expect(top == CGRect(x: 0, y: 25, width: 3440, height: 695))
        #expect(bottom == CGRect(x: 0, y: 720, width: 3440, height: 720))
    }

    @Test func unsplitScreenKeepsItsBounds() {
        guard let (core, screen, _) = core({ $0 }) else { return }
        #expect(
            core.tiler.visibleBounds(screen, for: SpaceID(1)) == Self.visible
        )
        #expect(core.splitAreaBounds().isEmpty)
    }

    @Test func parkingStaysTheWholeScreen() {
        guard
            let (core, screen, _) = core({ $0.splitting(0, .sideBySide) }),
            let space = core.state.workspaces[SpaceID(2)]
        else { return }
        let input = core.tiler.layoutInput(
            state: core.state,
            space: space,
            screen: screen
        )
        #expect(input.context.parkBounds == Self.visible)
        #expect(input.context.bounds.minX >= 1720)
    }

    @Test func innerEdgeIsANeighbourButNotAPark() {
        guard let (core, _, _) = core({ $0.splitting(0, .sideBySide) })
        else { return }
        core.tiler.allScreenBounds = { [Self.visible] }
        let left = CGRect(x: 0, y: 25, width: 1720, height: 1415)
        let found = core.tiler.neighbors(around: left, on: Self.visible)
        #expect(found.right)
        #expect(!found.left)
        let lone = ScreenNeighbors.detect(
            around: Self.visible,
            among: [Self.visible]
        )
        #expect(found.parkCorner == lone.parkCorner)
    }
}
