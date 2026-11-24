import Foundation
import Testing

@testable import KiwiDesk

/// Settings ▸ Bars & Pocket grouped by bar (#3612, owner ruling
/// 2026-11-24): one Each bar and Pocket drawer whose spelled-out
/// rows follow `BarsRowOrder.kiwishelfEach`, each Per screen or area
/// row stacking a segmented Show over its Position, and the rows
/// after the container under one heading. Source scans, off the
/// main actor.
@Suite("Bars by bar wiring (#3612)")
struct BarsByBarWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let bars = "Sources/KiwiDesk/Settings/Components/Bars/"

    private func squashed(_ file: String) throws -> String {
        let url = Self.root.appendingPathComponent(Self.bars + file)
        let text = try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace)
            .joined()
        #expect(!text.isEmpty)
        return text
    }

    /// The needle that draws `key` inside the drawer.
    private func needle(_ key: SettingKey) -> String? {
        switch key {
        case .spaceBar(.spaceBarVisibility):
            "showRow(.spaceBar(.spaceBarVisibility))"
        case .layoutAppBar(.monocleAppBarVisibility):
            "showRow(.layoutAppBar(.monocleAppBarVisibility))"
        case .layoutAppBar(.scrollingAppBarVisibility):
            "showRow(.layoutAppBar(.scrollingAppBarVisibility))"
        case .kiwishelf(.pocketVisibility):
            "showRow(.kiwishelf(.pocketVisibility))"
        case .kiwishelf(.pocketDragReveal):
            "showRow(.kiwishelf(.pocketDragReveal))"
        case .kiwishelf(.spaceBarEdge): "spaceBarEdgeRow"
        case .kiwishelf(.appBarEdge): "appBarEdgeRow"
        case .kiwishelf(.pocketEdge): "pocketEdgeRow"
        case .kiwishelf(.spaceBarScreenEdge): ".kiwishelfSpaceBarScreenEdges)"
        case .kiwishelf(.spaceBarScreenVisibility):
            ".kiwishelfSpaceBarScreenShows)"
        case .kiwishelf(.appBarScreenEdge): ".kiwishelfAppBarScreenEdges)"
        case .kiwishelf(.appBarScreenVisibility):
            ".kiwishelfAppBarScreenShows)"
        case .kiwishelf(.pocketScreenEdge): ".kiwishelfPocketScreenEdges)"
        case .kiwishelf(.pocketPosition): "pocketPositionRows"
        default: nil
        }
    }

    @Test("the drawer draws its rows in the census order, by bar")
    func drawerFollowsTheOrder() throws {
        let edge = try squashed("KiwiShelfCard+Edge.swift")
        let start = try #require(
            edge.range(of: "SettingsCatalog.bars.kiwishelfEach,")
        )
        let end = try #require(
            edge.range(
                of: "privatefuncbarGroup",
                range: start.upperBound..<edge.endIndex
            )
        )
        let drawer = edge[start.upperBound..<end.lowerBound]
        var cursor = drawer.startIndex
        for key in BarsRowOrder.kiwishelfEach {
            let text = try #require(needle(key), "\(key.id)")
            let hit = try #require(
                drawer.range(of: text, range: cursor..<drawer.endIndex),
                "\(key.id) out of order or missing"
            )
            cursor = hit.upperBound
        }
        // One heading per bar.
        #expect(drawer.components(separatedBy: "barGroup(").count - 1 == 3)
    }

    @Test("an area row stacks a segmented Show over its Position")
    func areaRowsStack() throws {
        let drawer = try squashed("ScreenEdgesDrawer.swift")
        #expect(
            drawer.contains(
                "ifletshow{showStrip(show,row:row,spoken:spoken)}"
                    + "labelled(position){SegmentedPicker("
            )
        )
        #expect(!drawer.contains("pickerStyle(.menu)"))
        #expect(
            drawer.contains(
                "SegmentedPicker(spokenLabel:Self.qualified(spoken,label),"
                    + "selection:model.screenShowBinding(show,on:row.id),"
            )
        )
    }

    @Test("the rows after the container sit under one heading")
    func outOfViewHeading() throws {
        let card = try squashed("KiwiShelfCard.swift")
        #expect(card.contains("showGroupDivider()outOfViewGroupDivider()"))
        #expect(
            card.contains(
                "SettingsGroupHeading(title:SettingsCatalog.bars"
                    + ".kiwishelfOutOfView.text)"
                    + ".searchAnchored(SettingsCatalog.bars"
                    + ".kiwishelfOutOfView)"
                    + "ForEach(BarsRowOrder.kiwishelfOutOfView,"
            )
        )
        #expect(
            BarsRowOrder.kiwishelfOutOfView == [
                .kiwishelf(.menuBarIcon), .kiwishelf(.handleThickness),
                .kiwishelf(.revealStyle),
            ]
        )
    }
}
