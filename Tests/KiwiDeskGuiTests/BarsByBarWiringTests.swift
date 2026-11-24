import Foundation
import Testing

@testable import KiwiDesk

/// Settings ▸ Bars & Pocket grouped by bar (#3612, owner rulings
/// 2026-11-24): one Each bar and Pocket drawer, a Screen or area
/// picker heading its bar blocks, its spelled-out rows following
/// `BarsRowOrder.kiwishelfEach`, a picked area's rows editing that
/// area while the Pocket's every-screen rows grey, and the rows
/// after the container under one heading. Source scans, off the
/// main actor. The per-screen needles are the picker's anchors,
/// read in the order they are chained.
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
        let each = try squashed("KiwiShelfCard+Each.swift")
        let start = try #require(
            each.range(of: "SettingsCatalog.bars.kiwishelfEach,")
        )
        let end = try #require(
            each.range(
                of: "privatefuncbarGroup",
                range: start.upperBound..<each.endIndex
            )
        )
        let drawer = each[start.upperBound..<end.lowerBound]
        // The blocks draw in the order the drawer calls them.
        #expect(
            drawer.contains(
                "scopeRows(own)spaceBarBlockappBarBlockpocketBlock}"
            )
        )
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

    @Test("a picked area's rows edit it; the Pocket's others grey")
    func areaRowsEditTheArea() throws {
        let each = try squashed("KiwiShelfCard+Each.swift")
        for (show, edged, block) in [
            ("space", "spaceBarStyle", "spaceBar"),
            ("app", "appBarStyle", "appBar"),
        ] {
            #expect(
                each.contains(
                    "ifletkey=activeScope{"
                        + "areaShow(.\(show),on:key,bar:.\(block))"
                        + "areaEdge(\\.\(edged),on:key,bar:.\(block))"
                        + "}else{"
                )
            )
        }
        for row in [
            "showRow(.kiwishelf(.pocketVisibility))",
            "showRow(.kiwishelf(.pocketDragReveal))",
            "pocketPositionRows",
        ] {
            #expect(each.contains("everyScreen(scoped){\(row)}"))
        }
        #expect(
            each.contains(
                "ifscoped{HStack(alignment:.top,spacing:6){"
                    + "VStack(alignment:.leading,spacing:8){row()}"
                    + ".modifier(GreyOut(active:true,"
                    + "help:Self.everyScreenHelp))"
                    + "HelpButton(explanation:Self.everyScreenHelp)}"
            )
        )
        // A pick the list no longer holds reads as All screens.
        #expect(
            each.contains(
                "guardletscope=model.nav.barsScope,model.offersScreenScopes,"
                    + "model.screenScopes.contains(where:{$0.id==scope})"
                    + "else{returnnil}"
            )
        )
    }

    @Test("the picker greys on one screen and anchors every hit")
    func pickerIsWired() throws {
        let each = try squashed("KiwiShelfCard+Each.swift")
        #expect(
            each.contains(
                "help:offered?Self.scopeHelp:Self.oneScreenHelp"
            )
        )
        #expect(each.contains("}.modifier(GreyOut(active:!offered))}"))
        #expect(each.contains("letoffered=model.offersScreenScopes"))
        for child in [
            "kiwishelfSpaceBarScreenEdges", "kiwishelfSpaceBarScreenShows",
            "kiwishelfAppBarScreenEdges", "kiwishelfAppBarScreenShows",
            "kiwishelfPocketScreenEdges", "screenOrArea",
        ] {
            #expect(
                each.contains(
                    ".searchAnchored(SettingsCatalog.bars.kiwishelfEach"
                        + ".children.\(child))"
                )
            )
        }
        // The caption under All screens, and the shut summary.
        #expect(
            each.contains("ifactiveScope==nil,!own.isEmpty{note(")
        )
        #expect(each.contains("summary:own.isEmpty?nil:L("))
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

    /// The pick is navigation state (#3612): a Bars landing and
    /// leaving Bars clear it, so a bar-level row a hit names is
    /// drawn and Bars reopens on All screens, and the pop-up reads
    /// what the blocks edit.
    @Test("a landing and a reset clear the picked area")
    func landingClearsThePick() throws {
        let root = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/"
        )
        func flat(_ file: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            ).split(whereSeparator: \.isWhitespace).joined()
        }
        let reveal = try flat("SettingsView+Reveal.swift")
        #expect(
            reveal.contains(
                "ifresolved.destination==.bars{model.nav.barsScope=nil}"
            )
        )
        // `SettingsNavigationResetTests` holds the reset's clear.
        let shell = try flat("SettingsView.swift")
        #expect(
            shell.contains(
                ".onChange(of:model.destination){old,_in"
                    + "ifold==.bars{model.nav.barsScope=nil}}"
            )
        )
        let each = try squashed("KiwiShelfCard+Each.swift")
        #expect(each.contains("Picker(label,selection:scopeBinding)"))
        #expect(each.contains("get:{activeScope}"))
    }
}
