import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's Space pictures (#2777 rulings 6, 9 and 11): the look
/// they wear, the Space each lights, how a pin offline is named,
/// and the grid's reorder. Main-actor spend: model construction and
/// two source reads.
@MainActor
@Suite("Simple preview")
struct SimplePreviewTests {
    private func model(_ spaces: [String]) -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        let model = makeTestModel(defaults: defaults)
        model.config.spaces = spaces.map { SpaceID($0) }
        return model
    }

    /// The next tile's enter can land before this tile's leave.
    @Test("a leave clears only its own hover")
    func leaveKeepsTheNext() {
        let model = model(["a"])
        model.hoverSimple(.look("B"), inside: true)
        model.hoverSimple(.look("A"), inside: false)
        #expect(model.nav.simpleHover == .look("B"))
        model.hoverSimple(.look("B"), inside: false)
        #expect(model.nav.simpleHover == nil)
    }

    @Test("a hovered look is painted over the draft, not written")
    func lookHoverPaints() throws {
        let model = model(["a"])
        let look = try #require(
            model.core.bundledLooks.first {
                $0.match(model.config.settings) == .none
            }
        )
        let before = model.config.settings
        model.hoverSimple(.look(look.name), inside: true)
        #expect(model.simplePreviewSettings != before)
        #expect(model.config.settings == before)
        model.hoverSimple(.look("No such look"), inside: true)
        #expect(model.simplePreviewSettings == before)
        #expect(model.simplePreviewHover == nil)
    }

    @Test("a new visit forgets the hovered look")
    func visitResets() {
        let model = model(["a"])
        model.nav.simpleHover = .look("A")
        model.nav.resetSurfaces()
        #expect(model.nav.simpleHover == nil)
    }

    /// A fallback that is not the main screen is named as itself.
    @Test("an offline pin names a fallback that is not main as such")
    func fallbackSentence() {
        LocalizationManager.shared.select("en")
        let side = Display(
            id: DisplayID(2),
            name: "Side",
            frame: CGRect(x: 100, y: 0, width: 100, height: 100)
        )
        let elsewhere = SettingsModel.offlinePinSentence(
            waiting: "Dell",
            fallback: side,
            fallbackIsMain: false
        )
        #expect(elsewhere.contains("Side"))
        #expect(!elsewhere.contains("main screen"))
        let main = SettingsModel.offlinePinSentence(
            waiting: "Dell",
            fallback: side,
            fallbackIsMain: true
        )
        #expect(main.contains("the main screen"))
    }

    @Test("an offline pin names the screen it waits for and its fallback")
    func offlineSentence() {
        LocalizationManager.shared.select("en")
        let model = model(["a"])
        let core = model.core
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Built-in",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        let space = SpaceID("a")
        model.config.spacePins[space] = "Dell:200x100"
        let sentence = model.offlinePinSentence(space)
        #expect(sentence.contains("Dell"))
        #expect(sentence.contains("Built-in"))
        // Its one screen is the main one, and the sentence says so.
        #expect(sentence.contains("the main screen"))
    }

    /// A card drawing the stored settings would ignore a hovered
    /// look, and one lighting a fixed item would light the first
    /// Space on every card.
    @Test("a card's picture wears the hovered look and lights itself")
    func pictureReadsTheHover() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Simple/"
                    + "SimpleSpacePicture.swift"
            )
        let text = try SourceScan.strippedSource(at: file)
            .filter { !$0.isWhitespace }
        #expect(text.contains("letsettings=model.simplePreviewSettings"))
        #expect(text.contains("HomeCardBarsTile(settings:settings,"))
        #expect(
            text.contains(
                "activeSpace:model.config.spaces.firstIndex(of:space)??0,"
            )
        )
        #expect(!text.contains("config.settings"))
    }

    /// On one line of cards the drag crosses a card's middle
    /// sideways; between lines, or down a list, it crosses it
    /// vertically.
    @Test("a drag crosses a card along the line it moves on")
    func gridCrossing() {
        let card = CGRect(x: 200, y: 0, width: 200, height: 150)
        let left = CGPoint(x: 260, y: 140)
        let right = CGPoint(x: 340, y: 10)
        #expect(
            !SpaceReorder.crossed(
                card,
                at: left,
                forward: true,
                sameLine: true
            )
        )
        #expect(
            SpaceReorder.crossed(
                card,
                at: right,
                forward: true,
                sameLine: true
            )
        )
        #expect(
            SpaceReorder.crossed(
                card,
                at: left,
                forward: false,
                sameLine: true
            )
        )
        // Off the line, only the vertical middle counts.
        #expect(
            SpaceReorder.crossed(
                card,
                at: left,
                forward: true,
                sameLine: false
            )
        )
        #expect(
            !SpaceReorder.crossed(
                card,
                at: right,
                forward: true,
                sameLine: false
            )
        )
    }

    @Test("a grid drag reorders across lines")
    func gridRetarget() {
        let reorder = SpaceReorder(listSpace: "test")
        let spaces = ["a", "b", "c", "d"].map { SpaceID($0) }
        // Two per line: a b / c d.
        reorder.rowFrames = [
            spaces[0]: CGRect(x: 0, y: 0, width: 100, height: 80),
            spaces[1]: CGRect(x: 110, y: 0, width: 100, height: 80),
            spaces[2]: CGRect(x: 0, y: 90, width: 100, height: 80),
            spaces[3]: CGRect(x: 110, y: 90, width: 100, height: 80),
        ]
        // `a` along its line past `b`'s middle, above its vertical
        // middle, so only the sideways reading crosses.
        reorder.retarget(
            spaces[0],
            at: CGPoint(x: 170, y: 20),
            in: spaces,
            reduceMotion: true
        )
        #expect(reorder.dragOrder?.map(\.raw) == ["b", "a", "c", "d"])
        // Then down onto `d`, past its vertical middle.
        reorder.retarget(
            spaces[0],
            at: CGPoint(x: 150, y: 140),
            in: spaces,
            reduceMotion: true
        )
        #expect(reorder.dragOrder?.map(\.raw) == ["b", "c", "d", "a"])
    }

    /// The Spaces page's list judges a row by its height alone, so a
    /// pointer drifting out of the column sideways still reorders.
    @Test("a list drag reorders with the pointer outside the column")
    func listDrift() {
        let reorder = SpaceReorder(listSpace: "test")
        let spaces = ["a", "b", "c"].map { SpaceID($0) }
        reorder.rowFrames = [
            spaces[0]: CGRect(x: 0, y: 0, width: 300, height: 40),
            spaces[1]: CGRect(x: 0, y: 44, width: 300, height: 40),
            spaces[2]: CGRect(x: 0, y: 88, width: 300, height: 40),
        ]
        reorder.retarget(
            spaces[0],
            at: CGPoint(x: 420, y: 70),
            in: spaces,
            reduceMotion: true
        )
        #expect(reorder.dragOrder?.map(\.raw) == ["b", "a", "c"])
    }

    /// The well mode is the cards' alone: another writer would strip
    /// a schematic's own frame and caption wherever it reached.
    @Test("one view puts a schematic in a well")
    func fillsWellHasOneWriter() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sites: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let count = try SourceScan.strippedSource(at: file)
                .filter { !$0.isWhitespace }
                .occurrences(of: ".environment(\\.schematicFillsWell,true)")
            if count > 0 { sites[file.lastPathComponent] = count }
        }
        #expect(sites == ["SimpleSpacePicture.swift": 1])
    }
}
