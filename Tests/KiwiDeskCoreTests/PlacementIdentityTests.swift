import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The placement list (#3517 ruling 10 as amended): one placement
/// per area, an unsplit screen being one area 0 keyed by its bare
/// fingerprint; each area shows its own Space; a vanished area's
/// Spaces fall back to area 0; a reconnect re-mints from the
/// fingerprint.
@Suite("Placement identity")
struct PlacementIdentityTests {
    private let wide = Display(
        id: DisplayID(900_101),
        name: "LG UltraWide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func threeAreas() throws -> ScreenSplit {
        try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)?
                .splitting(1, .sideBySide)
        )
    }

    @Test func unsplitScreenIsOneAreaZero() {
        var ws = WorkspaceManager()
        ws.upsertDisplay(wide)
        let areas = ws.placements(of: wide.id)
        #expect(areas.count == 1)
        #expect(areas[0].area.id == 0)
        #expect(areas[0].key.description == wide.fingerprint)
        #expect(areas[0].frame == wide.frame)
    }

    @Test func splitScreenHasOnePlacementPerArea() throws {
        var ws = WorkspaceManager()
        ws.setAreaSplits([wide.fingerprint: try threeAreas()])
        ws.upsertDisplay(wide)
        let areas = ws.placements(of: wide.id)
        #expect(areas.map(\.area.id) == [0, 1, 2])
        #expect(
            areas.map(\.key.description) == [
                wide.fingerprint, "\(wide.fingerprint)#1",
                "\(wide.fingerprint)#2",
            ]
        )
        #expect(areas.map(\.frame.minX) == [0, 1720, 2580])
        #expect(areas.allSatisfy { $0.frame.height == 1440 })
    }

    @Test func stackedAreaFramesAreAppKit() throws {
        var ws = WorkspaceManager()
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .stacked)
        )
        ws.setAreaSplits([wide.fingerprint: split])
        ws.upsertDisplay(wide)
        let areas = ws.placements(of: wide.id)
        // Top (area 0) sits at the larger AppKit y.
        #expect(areas[0].frame.minY == 720)
        #expect(areas[1].frame.minY == 0)
    }

    @Test func eachAreaShowsItsOwnSpace() throws {
        var ws = WorkspaceManager()
        ws.setAreaSplits([wide.fingerprint: try threeAreas()])
        ws.upsertDisplay(wide)
        let areas = ws.placements(of: wide.id).map(\.id)
        for (i, area) in areas.enumerated() {
            ws.assign(SpaceID(i + 1), to: area)
            ws.assign(SpaceID(i + 11), to: area)
        }
        ws.activate(SpaceID(2))
        ws.show(SpaceID(13), on: areas[2])
        #expect(ws.activeSpace(on: areas[0]) == SpaceID(1))
        #expect(ws.activeSpace(on: areas[1]) == SpaceID(2))
        #expect(ws.activeSpace(on: areas[2]) == SpaceID(13))
        #expect(
            ws.visibleSpaces == [SpaceID(1), SpaceID(2), SpaceID(13)]
        )
        #expect(ws.display(of: SpaceID(13)) == wide.id)
        #expect(ws.spaces(on: wide.id).count == 6)
        ws.activate(SpaceID(11))
        #expect(ws.activeSpace(on: areas[1]) == SpaceID(2))
    }

    @Test func vanishedAreaFallsBackToAreaZero() throws {
        var ws = WorkspaceManager()
        let three = try threeAreas()
        ws.setAreaSplits([wide.fingerprint: three])
        ws.upsertDisplay(wide)
        let right = try #require(ws.placements(of: wide.id).last).id
        ws.assign(SpaceID(5), to: right)
        let merged = try #require(three.merging(1, 2)).split
        ws.setAreaSplits([wide.fingerprint: merged])
        #expect(ws.placement(of: SpaceID(5))?.area == 0)
    }

    @Test func reconnectRemintsFromTheFingerprint() throws {
        var ws = WorkspaceManager()
        ws.setAreaSplits([wide.fingerprint: try threeAreas()])
        ws.upsertDisplay(wide)
        ws.removeDisplay(wide.id)
        #expect(ws.placements(of: wide.id).isEmpty)
        let again = Display(
            id: DisplayID(900_102),
            name: wide.name,
            frame: wide.frame
        )
        ws.upsertDisplay(again)
        #expect(ws.placements(of: again.id).map(\.area.id) == [0, 1, 2])
    }

    @Test func splitThatDoesNotFitIsIgnored() throws {
        var ws = WorkspaceManager()
        let other = try #require(
            ScreenSplit.whole(width: 2560, height: 1440)
                .splitting(0, .sideBySide)
        )
        ws.setAreaSplits([wide.fingerprint: other])
        ws.upsertDisplay(wide)
        #expect(ws.placements(of: wide.id).count == 1)
    }

    @Test func displayAssignTakesTheLeadingArea() throws {
        var ws = WorkspaceManager()
        ws.setAreaSplits([wide.fingerprint: try threeAreas()])
        ws.upsertDisplay(wide)
        ws.assign(SpaceID(1), to: wide.id)
        #expect(ws.placement(of: SpaceID(1))?.area == 0)
    }
}
