import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A screen or area in the Screen or area picker is named as
/// Settings ▸ Screens names it (#3612): a connected area by
/// `areaName(_:on:)` ("Wide – Left"), a disconnected one by its
/// stored name, else its position in the stored split; a split
/// screen's areas list in reading order.
@MainActor
@Suite("Per screen or area row names (#3612)", .serialized)
struct PerScreenAreaNameTests {
    private let wide = Display(
        id: DisplayID(900_712),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )
    private let gone = "Gone:1920x1080"

    /// A draft whose profile holds the wide screen alone, split side
    /// by side, and a disconnected screen's split, its right area
    /// named `named` when given.
    private func model(named: String?) throws -> SettingsModel {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(wide)
        model.profileSummaries = [
            ProfileSummary(
                name: "Desk",
                profileID: .legacy(name: "Desk"),
                count: 1,
                sets: [[wide.fingerprint]],
                isDefault: false,
                matchesLive: false,
                matchesConnectedCount: false,
                spaceCount: 0,
                shortcutOverrideCount: 0
            )
        ]
        model.target = .storedProfile("Desk")
        var away = try #require(
            ScreenSplit.whole(width: 1920, height: 1080)
                .splitting(0, .sideBySide)
        )
        if let named {
            let right = try #require(away.areas.firstIndex { $0.id == 1 })
            away.areas[right].name = named
        }
        model.config.settings.displayAreas = [
            wide.fingerprint: try #require(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, .sideBySide)
            ),
            gone: away,
        ]
        model.config.settings.spaceBarStyle.visibilityOverride = [
            "\(gone)#1": .hidden
        ]
        return model
    }

    private func names(_ model: SettingsModel) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: model.screenEdgeRows(
                \.spaceBarStyle,
                show: .space
            ).map { ($0.id, $0.name) }
        )
    }

    @Test("a connected area reads as Settings ▸ Screens names it")
    func connectedAreasArePositional() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        let rows = names(model)
        #expect(rows[wide.fingerprint] == "Wide – Left")
        #expect(rows["\(wide.fingerprint)#1"] == "Wide – Right")
        #expect(rows["\(wide.fingerprint)#1"] == model.areaName(1, on: wide))
    }

    @Test("a disconnected area reads its stored name, else its position")
    func disconnectedAreasFallBack() throws {
        defer { LocalizationManager.shared.select(nil) }
        let named = names(try model(named: "Notes"))
        #expect(named["\(gone)#1"] == "Gone – Notes")
        let positional = names(try model(named: nil))
        #expect(positional["\(gone)#1"] == "Gone – Right")
    }

    @Test("a whole screen reads its own name")
    func wholeScreenIsItsName() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        model.config.settings.displayAreas = [:]
        let rows = names(model)
        #expect(rows[wide.fingerprint] == model.areaName(nil, on: wide))
    }

    @Test("a split screen's areas list in reading order, not A–Z")
    func areasListInReadingOrder() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        model.config.settings.displayAreas = [
            wide.fingerprint: try #require(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, .stacked)
            )
        ]
        let rows = model.screenEdgeRows(\.spaceBarStyle, show: .space)
            .filter { $0.present }
            .map(\.name)
        #expect(rows == ["Wide – Top", "Wide – Bottom"])
    }

    @Test("the picker lists each bar's rows once and marks own values")
    func scopesUnionTheBars() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        model.config.settings.kiwishelf.pocketEdges.edgeOverride = [
            "Elsewhere:800x600": .left
        ]
        let ids = model.screenScopes.map(\.id)
        #expect(ids.count == Set(ids).count)
        #expect(ids.contains("\(gone)#1"))
        #expect(ids.contains("Elsewhere:800x600"))
        #expect(model.hasOwnSettings("\(gone)#1"))
        #expect(model.hasOwnSettings("Elsewhere:800x600"))
        #expect(!model.hasOwnSettings(wide.fingerprint))
    }
}
