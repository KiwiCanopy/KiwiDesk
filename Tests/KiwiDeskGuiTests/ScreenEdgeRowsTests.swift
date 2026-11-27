import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiShelf ▸ Each bar ▸ Per screen (#1948): which screens get a
/// row — one per Screen N since #3647 — what each picker writes, the
/// bar rows that select nothing while their screens differ, and the
/// readers that ask every screen rather than the bars' own edges.
@MainActor
@Suite("Per screen bar edges (#1948)")
struct ScreenEdgeRowsTests {
    private let main = Display(
        id: DisplayID(1),
        name: "Color LCD",
        frame: CGRect(x: 0, y: 0, width: 1728, height: 1117)
    )
    private let dell = Display(
        id: DisplayID(2),
        name: "DELL U2720Q",
        frame: CGRect(x: 1728, y: 0, width: 2560, height: 1440)
    )
    private let absent = "Acer X32:3840x2160"

    /// A draft whose profile holds the main screen, two DELLs and
    /// an Acer that is not connected; the main screen and one DELL
    /// are, numbered left to right: the main screen 1, the DELL 2.
    private func model() -> SettingsModel {
        let model = makeTestModel()
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        // The DELL first, so a reader taking the first display
        // rather than the main one is told apart.
        core.state.workspaces.upsertDisplay(dell)
        core.state.workspaces.upsertDisplay(main)
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                profileID: .legacy(name: "Desk"),
                count: 4,
                sets: [
                    [
                        main.fingerprint, dell.fingerprint,
                        dell.fingerprint, absent,
                    ]
                ],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: false,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        model.target = .storedProfile("Desk")
        model.config.settings.spaceBarStyle.visibility = .always
        model.config.settings.spaceBarStyle.setEdge(.top)
        model.config.settings.appBarStyle.setEdge(.top)
        return model
    }

    @Test("one row per screen number, the connected ones first")
    func rowsAreOrdered() {
        let rows = model().screenEdgeRows(\.spaceBarStyle)
        #expect(rows.map(\.id) == ["1", "2", "3", "4"])
        #expect(rows.map(\.present) == [true, true, false, false])
    }

    @Test("the rows hide while the profile holds one screen")
    func oneScreenHides() {
        let model = model()
        #expect(model.offersScreenEdges(\.spaceBarStyle))
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                profileID: .legacy(name: "Desk"),
                count: 1,
                sets: [[main.fingerprint]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: true,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        #expect(!model.offersScreenEdges(\.spaceBarStyle))
    }

    /// An edge Lua stored for a screen outside the profile still
    /// draws a differing edge, so its row shows — on a one-screen
    /// profile too — and the other bar's drawer stays hidden.
    @Test("a screen with its own edge gets a row, even on one screen")
    func outsideScreenHasARow() {
        let model = model()
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                profileID: .legacy(name: "Desk"),
                count: 1,
                sets: [[main.fingerprint]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: true,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        model.config.settings.spaceBarStyle.edgeOverride = ["3": .left]
        #expect(model.offersScreenEdges(\.spaceBarStyle))
        #expect(!model.offersScreenEdges(\.appBarStyle))
        #expect(
            model.screenEdgeRows(\.spaceBarStyle).map(\.id) == ["1", "3"]
        )
    }

    /// Connected twins read the lower number's values, so the higher
    /// number takes no row, and one row would only repeat the bar
    /// row: no drawer for them.
    @Test("identical models alone offer no drawer")
    func twinsAloneOfferNothing() {
        let model = model()
        let core = model.core
        core.state.workspaces.removeDisplay(main.id)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(3),
                name: dell.name,
                frame: CGRect(x: 4288, y: 0, width: 2560, height: 1440)
            )
        )
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                profileID: .legacy(name: "Desk"),
                count: 2,
                sets: [[dell.fingerprint, dell.fingerprint]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: true,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        #expect(!model.offersScreenEdges(\.spaceBarStyle))
    }

    @Test("a screen's pick stores its edge; the bar's edge clears it")
    func pickStoresAndClears() {
        let model = model()
        let dell = "2"
        model.screenEdge(\.spaceBarStyle, on: dell).wrappedValue = .left
        #expect(
            model.config.settings.spaceBarStyle.edgeOverride == [dell: .left]
        )
        #expect(
            model.screenEdge(\.spaceBarStyle, on: dell).wrappedValue == .left
        )
        model.screenEdge(\.spaceBarStyle, on: dell).wrappedValue = .top
        #expect(model.config.settings.spaceBarStyle.edgeOverride.isEmpty)
    }

    /// The draft's own screen numbers are the scope: every number
    /// moved to one edge — the absent screens' included — collapses
    /// the map into the bar's edge, and leaving one out keeps it
    /// apart.
    @Test("a pick is judged over the draft's screens, absent ones too")
    func scopeIsTheDraft() {
        let model = model()
        for screen in ["1", "2", "3"] {
            model.screenEdge(\.appBarStyle, on: screen).wrappedValue = .left
        }
        let bar = model.config.settings.appBarStyle
        #expect(bar.edge == .top)
        #expect(bar.edge(on: "4") == .top)
        #expect(bar.screensDiffer)
        model.screenEdge(\.appBarStyle, on: "4").wrappedValue = .left
        #expect(model.config.settings.appBarStyle.edge == .left)
        #expect(model.config.settings.appBarStyle.edgeOverride.isEmpty)
    }

    @Test("a bar row selects nothing while its screens differ")
    func barRowShowsNoSelection() {
        let model = model()
        #expect(model.barEdge(\.spaceBarStyle).wrappedValue == .top)
        model.screenEdge(\.spaceBarStyle, on: "2")
            .wrappedValue = .left
        #expect(model.barEdge(\.spaceBarStyle).wrappedValue == nil)
        #expect(model.barEdge(\.appBarStyle).wrappedValue == .top)
        #expect(model.barEdgeMaster.wrappedValue == nil)
        // A pick on the bar row puts it there on every screen.
        model.barEdge(\.spaceBarStyle).wrappedValue = .bottom
        #expect(model.config.settings.spaceBarStyle.edgeOverride.isEmpty)
        #expect(model.barEdge(\.spaceBarStyle).wrappedValue == .bottom)
    }

    @Test("order and minimum stay live where some screen fuses the bars")
    func fusedOnOneScreen() {
        let model = model()
        model.barEdge(\.appBarStyle).wrappedValue = .bottom
        #expect(
            BarsGates(settings: model.config.settings).bothBarsReason
                == .barsSplit
        )
        model.screenEdge(\.appBarStyle, on: "2")
            .wrappedValue = .top
        #expect(
            BarsGates(settings: model.config.settings).bothBarsReason
                == nil
        )
    }

    @Test("the front-app colour is live where some screen draws the name")
    func frontAppOnOneScreen() {
        let model = model()
        model.config.settings.kiwishelf.iconSource = .appImage
        model.config.settings.spaceBarStyle.showFrontApp = true
        model.barEdge(\.spaceBarStyle).wrappedValue = .left
        #expect(
            ColorsAndGlassGates(settings: model.config.settings)
                .focusedItemInert
        )
        model.screenEdge(\.spaceBarStyle, on: "2")
            .wrappedValue = .top
        #expect(
            !ColorsAndGlassGates(settings: model.config.settings)
                .focusedItemInert
        )
    }

    @Test("the Home cards read the main screen's edges")
    func homeIsTheMainScreen() {
        let model = model()
        model.screenEdge(\.spaceBarStyle, on: "1")
            .wrappedValue = .bottom
        #expect(model.homeSettings.spaceBarStyle.edge == .bottom)
        #expect(model.homeSettings.appBarStyle.edge == .top)
    }
}
