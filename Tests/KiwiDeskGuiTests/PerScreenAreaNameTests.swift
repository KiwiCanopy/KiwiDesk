import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A screen or area in the Screen or area picker is named as
/// Settings ▸ Screens names it (#3612): an area of a number a
/// connected screen holds by `areaName(_:on:)` ("Wide – Left"), one
/// no screen holds as "Screen N" with its stored name, else its
/// position in the stored split (#3647); a split screen's areas list
/// in reading order.
@MainActor
@Suite("Per screen or area row names (#3612)", .serialized)
struct PerScreenAreaNameTests {
    private let wide = Display(
        id: DisplayID(900_712),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )
    private let gone = "Gone:1920x1080"

    /// A draft whose profile holds the wide screen and, in a second
    /// setup, a disconnected one, each its setup's Screen 1, so both
    /// take Screen 1's one split (#3647): side by side, its right
    /// area named `named` when given.
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
                sets: [[wide.fingerprint], [gone]],
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
            "1": ScreenShares(away, width: 1920, height: 1080)
        ]
        model.config.settings.spaceBarStyle.visibilityOverride = [
            "1#1": .hidden
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
        #expect(rows["1"] == "Wide – Left")
        #expect(rows["1#1"] == "Wide – Right")
        #expect(rows["1#1"] == model.areaName(1, on: wide))
    }

    @Test("a disconnected area reads its stored name, else its position")
    func disconnectedAreasFallBack() throws {
        defer { LocalizationManager.shared.select(nil) }
        let named = try model(named: "Notes")
        named.core.state.workspaces.removeDisplay(wide.id)
        #expect(names(named)["1#1"] == "Screen 1 – Notes")
        let positional = try model(named: nil)
        positional.core.state.workspaces.removeDisplay(wide.id)
        #expect(names(positional)["1#1"] == "Screen 1 – Right")
    }

    @Test("a whole screen reads its own name")
    func wholeScreenIsItsName() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        model.config.settings.displayAreas = [:]
        let rows = names(model)
        #expect(rows["1"] == model.areaName(nil, on: wide))
    }

    @Test("a split screen's areas list in reading order, not A–Z")
    func areasListInReadingOrder() throws {
        defer { LocalizationManager.shared.select(nil) }
        let model = try model(named: nil)
        model.config.settings.displayAreas = [
            "1": ScreenShares(
                try #require(
                    ScreenSplit.whole(width: 3440, height: 1440)
                        .splitting(0, .stacked)
                ),
                width: 3440,
                height: 1440
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
            "3": .left
        ]
        let ids = model.screenScopes.map(\.id)
        #expect(ids.count == Set(ids).count)
        #expect(ids.contains("1#1"))
        #expect(ids.contains("3"))
        #expect(model.hasOwnSettings("1#1"))
        #expect(model.hasOwnSettings("3"))
        #expect(!model.hasOwnSettings("1"))
    }

    @Test("an area no stored split places is numbered")
    func unplacedAreaIsNumbered() throws {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let split = try #require(
            ScreenSplit.whole(width: 1920, height: 1080)
                .splitting(0, .sideBySide)
        )
        #expect(
            SettingsModel.perScreenName(
                screen: "Gone",
                key: "\(gone)#5",
                splits: [gone: split]
            ) == "Gone – Area 6"
        )
    }
}
