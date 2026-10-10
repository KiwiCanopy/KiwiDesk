import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiShelf ▸ Each bar ▸ Per screen (#1948): which screens get a
/// row, what each picker writes, the bar rows that select nothing
/// while their screens differ, and the readers that ask every
/// screen rather than the bars' own edges.
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
    private let absent = "LG HDR 4K:3840x2160"

    /// A draft whose profile holds the main screen, two DELLs and
    /// an LG that is not connected; the main screen and one DELL
    /// are.
    private func model() -> SettingsModel {
        let model = makeTestModel()
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(main)
        core.state.workspaces.upsertDisplay(dell)
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
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
        model.reachPage = "Desk"
        model.config.settings.spaceBarStyle.enabled = true
        model.config.settings.spaceBarStyle.setEdge(.top)
        model.config.settings.appBarStyle.setEdge(.top)
        return model
    }

    @Test("connected screens first, then the rest, each A–Z")
    func rowsAreOrdered() {
        let rows = model().screenEdgeRows
        #expect(
            rows.map(\.id) == [main.fingerprint, dell.fingerprint, absent]
        )
        #expect(rows.map(\.present) == [true, true, false])
        // Identical models share one row, captioned with the count.
        #expect(rows.map(\.count) == [1, 2, 1])
    }

    @Test("the rows hide while the profile holds one screen")
    func oneScreenHides() {
        let model = model()
        #expect(model.offersScreenEdges)
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                count: 1,
                sets: [[main.fingerprint]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: true,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        #expect(!model.offersScreenEdges)
    }

    @Test("a screen's pick stores its edge; the bar's edge clears it")
    func pickStoresAndClears() {
        let model = model()
        let dell = dell.fingerprint
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

    /// The draft's own screens are the scope: every screen moved
    /// to one edge — the absent LG included — collapses the map
    /// into the bar's edge, and leaving the LG out keeps it apart.
    @Test("a pick is judged over the draft's screens, absent ones too")
    func scopeIsTheDraft() {
        let model = model()
        for screen in [main.fingerprint, dell.fingerprint] {
            model.screenEdge(\.appBarStyle, on: screen).wrappedValue = .left
        }
        let bar = model.config.settings.appBarStyle
        #expect(bar.edge == .top)
        #expect(bar.edge(on: absent) == .top)
        #expect(bar.screensDiffer)
        model.screenEdge(\.appBarStyle, on: absent).wrappedValue = .left
        #expect(model.config.settings.appBarStyle.edge == .left)
        #expect(model.config.settings.appBarStyle.edgeOverride.isEmpty)
    }

    @Test("a bar row selects nothing while its screens differ")
    func barRowShowsNoSelection() {
        let model = model()
        #expect(model.barEdge(\.spaceBarStyle).wrappedValue == .top)
        model.screenEdge(\.spaceBarStyle, on: dell.fingerprint)
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
        model.screenEdge(\.appBarStyle, on: dell.fingerprint)
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
            AdvancedColorsGates(settings: model.config.settings)
                .focusedItemInert
        )
        model.screenEdge(\.spaceBarStyle, on: dell.fingerprint)
            .wrappedValue = .top
        #expect(
            !AdvancedColorsGates(settings: model.config.settings)
                .focusedItemInert
        )
    }

    @Test("the Home cards read the main screen's edges")
    func homeIsTheMainScreen() {
        let model = model()
        model.screenEdge(\.spaceBarStyle, on: main.fingerprint)
            .wrappedValue = .bottom
        #expect(model.homeSettings.spaceBarStyle.edge == .bottom)
        #expect(model.homeSettings.appBarStyle.edge == .top)
    }
}
