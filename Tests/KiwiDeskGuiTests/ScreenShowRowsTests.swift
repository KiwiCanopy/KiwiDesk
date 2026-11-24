import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiShelf ▸ Each bar ▸ a picked area's Show (#3517 rulings 30,
/// 32; #3612):
/// a split screen takes a row per area, a one-screen profile with a
/// split screen still offers the rows, each row's Show menu writes
/// that area's own value, and a bar-level Show pick clears them.
@MainActor
@Suite("Per screen bar Show (#3517)")
struct ScreenShowRowsTests {
    private let wide = Display(
        id: DisplayID(900_711),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    /// A draft whose profile holds the wide screen alone, split side
    /// by side when `split`.
    private func model(split: Bool) throws -> SettingsModel {
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
        model.config.settings.spaceBarStyle.visibility = .always
        if split {
            model.config.settings.displayAreas = [
                wide.fingerprint: try #require(
                    ScreenSplit.whole(width: 3440, height: 1440)
                        .splitting(0, .sideBySide)
                )
            ]
        }
        return model
    }

    @Test("a split screen takes a row per area and is offered")
    func splitScreenRowsPerArea() throws {
        let whole = try model(split: false)
        #expect(!whole.offersScreenEdges(\.spaceBarStyle, show: .space))
        let split = try model(split: true)
        let rows = split.screenEdgeRows(\.spaceBarStyle, show: .space)
        #expect(rows.map(\.id) == [wide.fingerprint, "Wide:3440x1440#1"])
        #expect(split.offersScreenEdges(\.spaceBarStyle, show: .space))
    }

    @Test("an entry for an area the draft no longer has keeps a row")
    func leftoverEntryKeepsARow() throws {
        let model = try model(split: false)
        let area = "Wide:3440x1440#1"
        model.config.settings.spaceBarStyle.visibilityOverride = [
            area: .hidden
        ]
        model.config.settings.appBarStyle.visibilityOverride = [
            area: .auto
        ]
        #expect(
            model.screenEdgeRows(\.spaceBarStyle, show: .space).map(\.id)
                .contains(area)
        )
        #expect(
            model.screenEdgeRows(\.appBarStyle, show: .app).map(\.id)
                .contains(area)
        )
    }

    @Test("an area's Show writes its own value; the bar's stores none")
    func showWritesTheArea() throws {
        let model = try model(split: true)
        let area = "Wide:3440x1440#1"
        model.screenShowBinding(.space, on: area).wrappedValue = .hidden
        #expect(
            model.config.settings.spaceBarStyle.visibilityOverride
                == [area: .hidden]
        )
        #expect(model.screenShow(.space, on: wide.fingerprint) == .always)
        model.screenShowBinding(.space, on: area).wrappedValue = .always
        #expect(model.config.settings.spaceBarStyle.visibilityOverride.isEmpty)
        // The App Bar's Per layout clears; a value always stores.
        model.screenShowBinding(.app, on: area).wrappedValue = .auto
        #expect(model.screenShow(.app, on: area) == .auto)
        model.screenShowBinding(.app, on: area).wrappedValue = nil
        #expect(model.config.settings.appBarStyle.visibilityOverride.isEmpty)
        #expect(model.screenShow(.app, on: area) == nil)
    }

    @Test("a bar-level Show pick clears that bar's areas (ruling 32)")
    func barPickClears() throws {
        let model = try model(split: true)
        let area = "Wide:3440x1440#1"
        model.screenShowBinding(.space, on: area).wrappedValue = .hidden
        model.screenShowBinding(.app, on: area).wrappedValue = .hidden
        model.barShowBinding(.appBar(.monocle)).wrappedValue = .auto
        #expect(model.config.settings.appBarStyle.visibilityOverride.isEmpty)
        #expect(
            !model.config.settings.spaceBarStyle.visibilityOverride.isEmpty
        )
        model.barShowBinding(.spaceBar).wrappedValue = .auto
        #expect(model.config.settings.spaceBarStyle.visibilityOverride.isEmpty)
        model.screenShowBinding(.space, on: area).wrappedValue = .hidden
        model.screenShowBinding(.app, on: area).wrappedValue = .hidden
        model.barVisibilityMaster.wrappedValue = .always
        #expect(model.config.settings.spaceBarStyle.visibilityOverride.isEmpty)
        #expect(model.config.settings.appBarStyle.visibilityOverride.isEmpty)
    }

    @Test("an area picked edits both bars' Show")
    func drawersAreWired() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Bars/"
                        + "KiwiShelfCard+Each.swift"
                )
        )
        #expect(source.contains("areaShow(.space, on: key"))
        #expect(source.contains("areaShow(.app, on: key"))
        let rows = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Bars/"
                        + "KiwiShelfCard+Placement.swift"
                )
        )
        #expect(rows.components(separatedBy: "barShowBinding(").count - 1 == 3)
    }
}
