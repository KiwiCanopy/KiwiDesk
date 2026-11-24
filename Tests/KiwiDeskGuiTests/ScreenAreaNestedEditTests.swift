import CoreGraphics
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
}
