import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The fit rule on the Screens cards (#3647 ▸ no-fit ruling): a
/// number whose split cannot fit a screen greys there while another
/// order fits, nothing greys where no order fits, and a screen that
/// draws its number whole names the axis that failed.
@Suite("Screen number fit on the cards (#3647)", .serialized)
@MainActor
struct ScreenNumberFitTests {
    private let laptop = Display(
        id: DisplayID(900_821),
        name: "Laptop",
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )
    private let wide = Display(
        id: DisplayID(900_822),
        name: "Wide",
        frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440)
    )

    /// Laptop is Screen 1, and Screen 1 is split in halves under a
    /// floor of `floor` points.
    private func makeModel(
        _ other: Display? = nil,
        floor: CGFloat = 800
    ) -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647g-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(laptop)
        core.state.workspaces.upsertDisplay(other ?? wide)
        let model = makeTestModel(core: core)
        model.reload()
        model.config.settings.minWindowSizes = MinWindowSizes(
            all: .square(floor)
        )
        model.config.settings.displayAreas[number: 1] = ScreenShares(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 500, h: 1000),
                ScreenArea(id: 1, x: 500, y: 0, w: 500, h: 1000),
            ]
        )
        model.cleanConfig = model.config
        return model
    }

    @Test("a number that cannot fit greys while another order fits")
    func unfitNumberGreys() {
        let model = makeModel()
        #expect(model.screenNumber(of: laptop) == 1)
        // The laptop's halves fall under the floor: it draws whole,
        // naming the side-by-side cut.
        #expect(model.unsplitAxis(of: laptop) == .sideBySide)
        #expect(model.unsplitAxis(of: wide) == nil)
        // Taking Screen 1 on the wide screen fits.
        #expect(model.screenNumberFits(1, for: wide))
        model.useScreenNumber(1, for: wide)
        #expect(model.unsplitAxis(of: wide) == nil)
        // Handing it back to the laptop would not.
        #expect(!model.screenNumberFits(1, for: laptop))
        #expect(model.screenNumberFits(2, for: laptop))
    }

    @Test("where no order fits, every number stays enabled")
    func nothingFitsGreysNothing() {
        let narrow = Display(
            id: DisplayID(900_823),
            name: "Narrow",
            frame: CGRect(x: 1512, y: 0, width: 1000, height: 900)
        )
        let model = makeModel(narrow)
        #expect(model.screenNumberFits(1, for: narrow))
        #expect(model.screenNumberFits(2, for: narrow))
        #expect(model.unsplitAxis(of: laptop) == .sideBySide)
    }

    @Test("a split that fits draws as stored")
    func fittingSplitDrawsSplit() {
        let model = makeModel(floor: 300)
        #expect(model.unsplitAxis(of: laptop) == nil)
        #expect(model.screenNumberFits(1, for: wide))
    }

    /// A floor raised under a selected area draws its screen whole,
    /// so the selection lets go of the area and the caption shows.
    @Test("a floor that draws a screen whole lets go of its area")
    func floorRaiseNormalizesTheSelection() throws {
        let model = makeModel(floor: 300)
        let split = model.draftSplits
        #expect(split[laptop.fingerprint] != nil)
        model.config.settings.minWindowSizes = MinWindowSizes(
            all: .square(800)
        )
        // The selection keys on the drawn splits, which moved.
        #expect(model.draftSplits != split)
        #expect(model.areaSplit(of: laptop) == nil)
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/ScreensSection.swift"
            )
        let source = try SourceScan.normalizedFile(file)
        #expect(
            source.contains(
                ".onChange(of: model.draftSplits) {\n"
                    + "selection = normalized(selection,"
            )
        )
    }
}
