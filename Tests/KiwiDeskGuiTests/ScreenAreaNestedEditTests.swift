import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Screens editor on a nested split (#3541): both directions on
/// offer, Merge as one pull-down past two neighbours, Even Out on the
/// selection's own run, and the names it words.
@MainActor
@Suite("Screen area nested edits")
struct ScreenAreaNestedEditTests {
    private func model() -> (SettingsModel, Display) {
        let model = makeTestModel()
        let screen = Display(
            id: DisplayID(78),
            name: "Wide",
            frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
        )
        model.core.state.workspaces.upsertDisplay(screen)
        model.config.settings.minWindowSizes =
            MinWindowSizes(all: .square(300))
        return (model, screen)
    }

    /// Left | Middle Top / Middle Bottom | Right.
    private func tJunction(_ model: SettingsModel, _ screen: Display) {
        model.splitArea(0, on: screen, .sideBySide)
        model.splitArea(1, on: screen, .sideBySide)
        model.evenOutAreas(holding: 0, on: screen)
        model.splitArea(1, on: screen, .stacked)
    }

    @Test func bothDirectionsAreOffered() {
        #expect(ScreenAreaEditing.axes == ScreenAreaCut.Axis.allCases)
    }

    @Test func mergePullsDownPastTwoNeighbours() {
        #expect(!ScreenAreaEditing.mergePullsDown([1, 2]))
        #expect(ScreenAreaEditing.mergePullsDown([1, 2, 3]))
    }

    @Test func evenOutStaysInTheSelectionsRun() throws {
        let (model, screen) = model()
        tJunction(model, screen)
        let before = try #require(model.areaSplit(of: screen))
        let inner = try #require(before.run(holding: 1))
        let tall = try #require(
            before.setting(
                member: 0,
                of: inner,
                to: 1000,
                givingWay: 1,
                floor: 300
            )
        ).split
        model.writeAreaSplit(tall, on: screen)
        #expect(model.canEvenOut(holding: 1, on: screen))
        #expect(!model.canEvenOut(holding: 0, on: screen))
        model.evenOutAreas(holding: 1, on: screen)
        let after = try #require(model.areaSplit(of: screen))
        #expect(after.run(holding: 1)?.lengths == [720, 720])
        #expect(after.run(holding: 0) == tall.run(holding: 0))
    }

    @Test func nestedNamesAreWordedWhole() throws {
        LocalizationManager.shared.select("en")
        let (model, screen) = model()
        tJunction(model, screen)
        let split = try #require(model.areaSplit(of: screen))
        let names = ScreenArea.readingOrder(split.areas).compactMap {
            model.areaLabel($0.id, on: screen)
        }
        #expect(names == ["Left", "Middle Top", "Right", "Middle Bottom"])
        let run = try #require(split.run(holding: 0))
        #expect(model.memberLabel(1, of: run, on: screen) == "Middle")
        #expect(
            ScreenAreaWords.position([.left, .top]) == "Top Left"
                && ScreenAreaWords.position([.top, .middle]) == "Top Middle"
                && ScreenAreaWords.position([.middle, .middle]) == "Middle"
        )
    }

    /// The Merge row's fit ladder lays out from wide to narrow,
    /// with short names and with long custom ones (#3271's trap).
    @Test func mergeRowLaysOutAtEveryWidth() throws {
        LocalizationManager.shared.select("en")
        let (model, screen) = model()
        tJunction(model, screen)
        for name in [nil, String(repeating: "Wide name ", count: 4)] {
            if let name {
                model.renameArea(1, on: screen, to: name + "1")
                model.renameArea(3, on: screen, to: name + "2")
            }
            let editor = ScreenAreaEditor(
                model: model,
                display: screen,
                area: 0,
                rename: .constant(nil),
                sizes: .constant(nil),
                givingWay: .constant([]),
                percent: .constant(false),
                select: { _ in }
            )
            for width: CGFloat in [1200, 640, 320, 120] {
                let host = NSHostingView(rootView: editor)
                host.frame = NSRect(x: 0, y: 0, width: width, height: 400)
                host.layoutSubtreeIfNeeded()
                #expect(host.fittingSize.height > 0)
            }
        }
    }

    /// A drag lights a divider only where Core reads it onto the
    /// dragged one's cut: in line AND touching (#3541 ruling 5).
    @Test func aDragLightsOnlyTheDividersItJoined() throws {
        let whole = ScreenSplit.whole(width: 3000, height: 900)
        func cuts(_ split: ScreenSplit) throws -> [ScreenAreaCut] {
            try #require(
                ScreenAreaCuts.cuts(of: split.areas, width: 3000, height: 900)
            )
        }
        // Rows, the first and last split side by side at their
        // middles; `rows` 2 makes them touch, 3 puts a whole row
        // between them.
        func lit(rows: Int, at position: Int) throws -> Bool {
            var split = whole
            for _ in 1..<rows {
                let last = split.areas.map(\.id).max() ?? 0
                split = try #require(split.splitting(last, .stacked))
            }
            let top = try #require(split.areas.min { $0.y < $1.y })
            let bottom = try #require(split.areas.max { $0.y < $1.y })
            split = try #require(split.splitting(bottom.id, .sideBySide))
            let low = try #require(
                try cuts(split).first { $0.axis == .sideBySide }
            )
            split = split.moving(low, to: 2000, floor: 100).split
            split = try #require(split.splitting(top.id, .sideBySide))
            let upright = try cuts(split).filter { $0.axis == .sideBySide }
            let lead = try #require(upright.min { $0.start < $1.start })
            let other = try #require(upright.max { $0.start < $1.start })
            let target = other.position + position
            let landed = split.moving(lead, to: target, floor: 100)
            let drag = AreaDividerDrag(
                split: landed.split,
                snap: .divider,
                cut: 0,
                position: landed.position,
                landed: try cuts(landed.split).first {
                    $0.holds(lead, at: landed.position)
                }
            )
            #expect(drag.landed != nil)
            return drag.joins(other)
        }
        #expect(try lit(rows: 2, at: 0))
        #expect(try !lit(rows: 2, at: 50))
        #expect(try !lit(rows: 3, at: 0))
    }

    /// Every split two runs deep, each run two or three wide, and
    /// three deep where Core numbers: Core's paths and the GUI's
    /// name table are one contract, so every area words to a name
    /// and no two on a screen share one.
    @Test func everyReachablePathWordsToAUniqueName() throws {
        LocalizationManager.shared.select("en")
        var checked = 0
        for split in Self.splits() {
            let names = split.positions.values.map {
                ScreenAreaWords.position($0)
            }
            #expect(!names.contains(""), "\(split.positions)")
            #expect(Set(names).count == names.count, "\(names)")
            checked += 1
        }
        #expect(checked > 50)
    }

    private static func splits() -> [ScreenSplit] {
        let whole = ScreenSplit.whole(width: 3600, height: 3600)
        var out: [ScreenSplit] = []
        for axis in ScreenAreaCut.Axis.allCases {
            let other: ScreenAreaCut.Axis =
                axis == .sideBySide ? .stacked : .sideBySide
            for wide in [2, 3] {
                var root = whole
                for _ in 1..<wide {
                    let last = root.areas.map(\.id).max() ?? 0
                    root = root.splitting(last, axis, floor: 1) ?? root
                }
                let leaves = root.areas.map(\.id)
                // Every subset of leaves split again, two or three wide.
                for mask in 0..<(1 << leaves.count) {
                    for inner in [2, 3] {
                        var split = root
                        for (bit, id) in leaves.enumerated()
                        where mask & (1 << bit) != 0 {
                            split =
                                split.splitting(id, other, floor: 1) ?? split
                            if inner == 3 {
                                let fresh = split.nextID - 1
                                split =
                                    split.splitting(fresh, other, floor: 1)
                                    ?? split
                            }
                        }
                        out.append(split)
                        // And one area three runs deep.
                        if let deep = split.areas.last.flatMap({
                            split.splitting($0.id, axis, floor: 1)
                        }) {
                            out.append(deep)
                        }
                    }
                }
            }
        }
        return out
    }

    /// The menu and the editor offer the axes and branch Merge
    /// through the one rule, never a list or a count of their own.
    @Test func editorAndMenuTakeTheSharedRules() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let dir = "Sources/KiwiDesk/Settings/Components/Screens/"
        func source(_ name: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(dir + name),
                    encoding: .utf8
                )
            )
        }
        let menu = try source("ScreenAreaMenu.swift")
        let editor = try source("ScreenAreaEditor.swift")
        #expect(!menu.isEmpty && !editor.isEmpty)
        #expect(menu.contains("ForEach(ScreenAreaEditing.axes,"))
        #expect(editor.contains("let axes = ScreenAreaEditing.axes\n"))
        #expect(
            editor.contains("if ScreenAreaEditing.mergePullsDown(neighbours)")
        )
        // A neighbour's button says its name and speaks the action;
        // a pair too wide falls back to the pull-down.
        let button = try #require(
            editor.range(of: "private func mergeButton(")
        )
        let rest = editor[button.lowerBound...]
        let end = try #require(rest.range(of: "\n    }\n"))
        let body = String(rest[..<end.upperBound])
        #expect(
            body.contains(
                "let title = ScreenAreaEditing.mergeTitle("
                    + "other, model, display)"
            )
        )
        #expect(body.contains(".help(title)"))
        #expect(body.contains(".accessibilityLabel(title)"))
        #expect(body.contains("Button(model.areaLabel(other, on: display)"))
        #expect(editor.contains("ViewThatFits(in: .horizontal)"))
        // A joined divider lights through every style the dragged
        // one takes.
        let divider = try source("ScreenAreaDivider.swift")
        #expect(divider.contains("dragging || drag?.joins(cut) == true"))
        #expect(!divider.contains("if dragging {"))
        #expect(!divider.contains("dragging ? 2"))
        #expect(!divider.contains("dragging\n"))
        // The hint stands in for the editor while nothing is selected.
        let section = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/ScreensSection.swift"
            ),
            encoding: .utf8
        )
        #expect(
            SourceScan.stripComments(section).contains(
                "} else {\n            Text(\n                L(\n"
                    + "                    \"monitors.selection.hint\""
            )
        )
    }
}
