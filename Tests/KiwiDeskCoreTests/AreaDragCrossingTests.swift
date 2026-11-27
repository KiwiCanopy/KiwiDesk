import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The live drag crossing between areas of one split screen
/// (#3574): the dwell arms on an area seam as it does on a screen
/// seam, and its landing files the window into the other area's
/// Space. An unsplit screen is the control: it has no seam to arm.
@Suite("Drag crossing between areas", .serialized)
@MainActor
struct AreaDragCrossingTests {
    private let wide = Display(
        id: DisplayID(900_621),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core(_ axis: ScreenAreaCut.Axis?) throws -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        if let axis {
            core.tiler.settings.displayAreas.store(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, axis),
                on: wide.fingerprint,
                order: core.liveScreenOrder
            )
        }
        let areas = core.state.workspaces.placements(of: wide.id)
        for (index, area) in areas.enumerated() {
            core.state.workspaces.assign(
                SpaceID("\(index + 1)"),
                to: area.id
            )
        }
        core.state.workspaces.activate(SpaceID("1"))
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 1,
                        appName: "A\(raw)"
                    )
                )
            )
        }
        core.dragCrossing.displayAt = { [wide] _ in wide.id }
        core.dragCrossing.dwell = 0.01
        core.drag.isMousePressed = { true }
        return core
    }

    /// The Cocoa point `offset` into the screen's own points.
    private func cocoa(_ offset: CGPoint) -> CGPoint {
        let whole = GeometryUtils.flip(
            wide.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        return GeometryUtils.axPoint(
            CGPoint(x: whole.minX + offset.x, y: whole.minY + offset.y)
        )
    }

    private func area(_ core: KiwiCore, _ index: Int) -> PlacementID {
        core.state.workspaces.placements(of: wide.id)[index].id
    }

    /// The wired resolver reads the Cocoa cursor as the area under
    /// it, side by side and stacked.
    @Test func resolverAnswersTheAreaUnderTheCursor() throws {
        let side = try core(.sideBySide)
        #expect(
            side.dragCrossing.placementAt(cocoa(CGPoint(x: 100, y: 700)))
                == area(side, 0)
        )
        #expect(
            side.dragCrossing.placementAt(cocoa(CGPoint(x: 3000, y: 700)))
                == area(side, 1)
        )
        let stacked = try core(.stacked)
        #expect(
            stacked.dragCrossing.placementAt(
                cocoa(CGPoint(x: 1000, y: 1300))
            ) == area(stacked, 1)
        )
    }

    /// A dwell in the other area lands the window in that area's
    /// Space and makes it the active one.
    @Test func dwellInTheOtherAreaCrosses() async throws {
        let core = try core(.sideBySide)
        let id = WindowID(1)
        let point = cocoa(CGPoint(x: 3000, y: 700))
        core.drag.cursorLocation = { point }
        core.updateDragCrossing(id, cursor: point)
        let dwell = core.dragCrossing.dwellTask
        #expect(dwell != nil, "the area seam armed no dwell")
        await dwell?.value
        #expect(core.state.workspaces.space(of: id) == "2")
        #expect(core.activeSpace?.id == "2")
        #expect(core.dragCrossing.hasCrossed(id))
        #expect(core.dragCrossing.origin(for: id)?.space == "1")
        // The drop at the same cursor names the Space the dwell
        // filed into, so the release re-files nothing.
        #expect(core.dropDestination() == "2")
    }

    /// On a stacked split the dwell crosses into the lower area, the
    /// drop keeps it there and ends the gesture, and a second
    /// gesture crosses back into the upper area.
    @Test func stackedCrossDropAndBack() async throws {
        let core = try core(.stacked)
        let id = WindowID(1)
        let lower = cocoa(CGPoint(x: 1000, y: 1300))
        core.drag.cursorLocation = { lower }
        core.updateDragCrossing(id, cursor: lower)
        let down = core.dragCrossing.dwellTask
        #expect(down != nil, "the stacked seam armed no dwell")
        await down?.value
        #expect(core.state.workspaces.space(of: id) == "2")
        core.handleDragEnd(
            id,
            start: CGRect(x: 0, y: 0, width: 500, height: 500),
            frame: CGRect(x: 0, y: 900, width: 400, height: 400)
        )
        #expect(core.state.workspaces.space(of: id) == "2")
        #expect(!core.dragCrossing.hasCrossed(id))
        let upper = cocoa(CGPoint(x: 1000, y: 100))
        core.drag.cursorLocation = { upper }
        core.updateDragCrossing(id, cursor: upper)
        let back = core.dragCrossing.dwellTask
        #expect(back != nil, "the way back armed no dwell")
        await back?.value
        #expect(core.state.workspaces.space(of: id) == "1")
    }

    /// A dwell whose cursor is back in the home area by fire time
    /// crosses nothing.
    @Test func staleFireStaysHome() async throws {
        let core = try core(.sideBySide)
        let id = WindowID(1)
        let point = cocoa(CGPoint(x: 3000, y: 700))
        core.updateDragCrossing(id, cursor: point)
        let dwell = core.dragCrossing.dwellTask
        #expect(dwell != nil, "the area seam armed no dwell")
        let home = cocoa(CGPoint(x: 100, y: 700))
        core.drag.cursorLocation = { home }
        await dwell?.value
        #expect(core.state.workspaces.space(of: id) == "1")
        #expect(!core.dragCrossing.hasCrossed(id))
    }

    /// A flick released in the other area before any dwell: the drop
    /// names that area's Space, not the screen's active one.
    @Test func flickDropNamesTheAreaUnderTheCursor() throws {
        let core = try core(.sideBySide)
        let point = cocoa(CGPoint(x: 3000, y: 700))
        core.drag.cursorLocation = { point }
        #expect(core.activeSpace?.id == "1")
        #expect(core.dropDestination() == "2")
    }

    /// The pointer still in the window's own area arms nothing.
    @Test func ownAreaArmsNothing() throws {
        let core = try core(.sideBySide)
        let point = cocoa(CGPoint(x: 100, y: 700))
        core.updateDragCrossing(WindowID(1), cursor: point)
        #expect(core.dragCrossing.dwellTask == nil)
    }

    /// An unsplit screen is one area: no point on it arms a dwell.
    @Test func unsplitScreenArmsNothing() throws {
        let core = try core(nil)
        let point = cocoa(CGPoint(x: 3000, y: 700))
        core.updateDragCrossing(WindowID(1), cursor: point)
        #expect(core.dragCrossing.dwellTask == nil)
    }
}
