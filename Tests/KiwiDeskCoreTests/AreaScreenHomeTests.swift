import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1010 predicate on a split screen (#3517 ruling 5): a landing
/// is an area, so a window landing in another area takes THAT
/// area's shown Space, and one landing in its own area stays.
@Suite("Area screen home")
struct AreaScreenHomeTests {
    private let wide = Display(
        id: DisplayID(900_301),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func state() throws -> (StateCoordinator, [PlacementID]) {
        var state = StateCoordinator(defaultSpace: SpaceID("1"))
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        state.workspaces.setAreaSplits([wide.fingerprint: split])
        state.workspaces.upsertDisplay(wide)
        let areas = state.workspaces.placements(of: wide.id).map(\.id)
        state.workspaces.assign(SpaceID("1"), to: areas[0])
        state.workspaces.assign(SpaceID("2"), to: areas[1])
        state.workspaces.assign(SpaceID("3"), to: areas[1])
        state.workspaces.activate(SpaceID("1"))
        state.workspaces.show(SpaceID("3"), on: areas[1])
        return (state, areas)
    }

    private let window = ManagedWindow(
        id: WindowID(11),
        pid: 900_011,
        appName: "App",
        frame: CGRect(x: 2000, y: 100, width: 800, height: 600)
    )

    @Test func otherAreaTakesItsShownSpace() throws {
        let (state, areas) = try state()
        let home = state.screenHome(
            of: window,
            leaving: SpaceID("1"),
            landingOn: wide.id,
            in: areas[1]
        )
        #expect(home == SpaceID("3"))
    }

    @Test func ownAreaStays() throws {
        let (state, areas) = try state()
        let home = state.screenHome(
            of: window,
            leaving: SpaceID("1"),
            landingOn: wide.id,
            in: areas[0]
        )
        #expect(home == nil)
    }

    @Test func hiddenSpaceInItsOwnAreaStays() throws {
        let (state, areas) = try state()
        // Space 2 sits behind 3 in the landing area: still home.
        let home = state.screenHome(
            of: window,
            leaving: SpaceID("2"),
            landingOn: wide.id,
            in: areas[1]
        )
        #expect(home == nil)
    }

    @Test func unsplitLandingKeepsTheScreenRule() throws {
        let (state, _) = try state()
        let home = state.screenHome(
            of: window,
            leaving: SpaceID("1"),
            landingOn: wide.id,
            in: nil
        )
        #expect(home == nil)
    }

    @Test func foldTakesTheArrivalArea() throws {
        var (state, areas) = try state()
        state.apply(.windowCreated(window))
        #expect(state.workspaces.space(of: window.id) == SpaceID("1"))
        state.apply(.windowDestroyed(window.id, wasMinimized: false))
        // Back on the same screen, in the other area.
        state.arrivalDisplay = wide.id
        state.arrivalPlacement = areas[1]
        let effects = state.apply(.windowCreated(window))
        #expect(effects.rehomedToScreenSpace == SpaceID("3"))
        #expect(state.workspaces.space(of: window.id) == SpaceID("3"))
    }
}
