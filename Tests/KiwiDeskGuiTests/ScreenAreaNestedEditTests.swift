import CoreGraphics
import Foundation
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
    }
}
