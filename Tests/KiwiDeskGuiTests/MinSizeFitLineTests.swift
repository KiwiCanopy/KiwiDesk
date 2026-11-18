import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The minimum window size's band and its fit readout (#3461):
/// the band reaches a third of the widest screen targeted and
/// holds every value the starter seeds; the line names the screen
/// and both counts; and the rows draw it under the master while
/// the layouts agree, on each counting row while they differ.
@Suite("Minimum size band and fit line")
@MainActor
struct MinSizeFitLineTests {
    @Test("the band reaches a third of 5120 and holds the seeds")
    func bandCoversTheTarget() {
        let range = MinSizeFields.range
        let step = MinSizeFields.step
        let third = 5120 / 3 / step * step
        #expect(range.upperBound >= third)
        let seeds = StarterTuning.minSizeRange
        #expect(range.lowerBound <= Int(seeds.lowerBound))
        #expect(range.upperBound >= Int(seeds.upperBound))
        #expect(range.lowerBound % step == 0)
        #expect(range.upperBound % step == 0)
    }

    @Test("the line names the screen and both counts")
    func sentences() {
        LocalizationManager.shared.select("en")
        let studio = ScreenLabel(name: "Studio")
        let fits = MinSizeFitLine.sentence(
            for: MinSizeFit(screen: studio, across: 7, down: 2)
        )
        #expect(fits == "Fits on Studio — Across: 7 · Down: 2")
        // Either axis at nothing takes the other sentence.
        for fit in [
            MinSizeFit(screen: studio, across: 0, down: 2),
            MinSizeFit(screen: studio, across: 3, down: 0),
        ] {
            #expect(
                MinSizeFitLine.sentence(for: fit)
                    == "Doesn't fit on Studio: a window there can't "
                    + "reach this size."
            )
        }
    }

    @Test("the master draws the line while agreed, the rows while not")
    func linesAreDrawn() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Layouts/"
                        + "MinWindowSizeRows.swift"
                )
        )
        let needles = [
            // The master's line, over the counted master layout.
            "if !model.minSizesDiffer {\n"
                + "                    MinSizeFitLine(fit: "
                + "counted[model.minSizeFitMaster])",
            // Each row's line while Mixed.
            "if model.minSizesDiffer {\n"
                + "                MinSizeFitLine(fit: fit)",
            // One read per pass, handed down to the rows.
            "let counted = fits()",
            "layoutRow($0, fit: fits[$0])",
            // A screen change counts again.
            "didChangeScreenParametersNotification",
            "{ _ in screens &+= 1 }",
            "_ = screens\n        return model.minSizeFits()",
        ]
        for needle in needles {
            #expect(source.occurrences(of: needle) == 1, "\(needle)")
        }
    }

    @Test("the counted layouts and the master's choice among them")
    func countedLayouts() {
        #expect(
            SettingsModel.minSizeFitLayouts == [.stack, .grid, .track, .bsp]
        )
        // A Scrolling-led profile counts its most-used counted
        // layout, never the Scrolling region the rows leave out.
        let model = makeTestModel()
        model.config.spaces = ["1", "2", "3"]
        model.config.spaceModes = [
            "1": .scrolling, "2": .scrolling, "3": .grid,
        ]
        #expect(model.minSizeMostUsed == .scrolling)
        #expect(model.minSizeFitMaster == .grid)
        // With none on a counted layout, BSP.
        model.config.spaceModes = ["1": .floating, "2": .monocle]
        model.config.spaces = ["1", "2"]
        #expect(model.minSizeFitMaster == .bsp)
    }

    /// The line is fed the draft's own values through Core, not
    /// an empty answer that would leave every needle above intact.
    @Test(
        "the model hands the rows the draft's counts",
        .enabled(if: !NSScreen.screens.isEmpty, "needs a screen")
    )
    func modelFeedsTheDraft() throws {
        let model = makeTestModel()
        model.core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 3110, height: 1270)
        }
        model.config.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 0, bottom: 0, left: 0, right: 0),
            inner: Gaps.Inner(horizontal: 10, vertical: 10)
        )
        model.config.settings.spaceBarStyle.visibility = .hidden
        model.config.settings.kiwishelf.pocketVisibility = .hidden
        model.setMinSize(300, axis: .width, for: nil)
        model.setMinSize(300, axis: .height, for: nil)
        model.setMinSize(600, axis: .width, for: .grid)
        let fits = model.minSizeFits()
        #expect(Set(fits.keys) == Set(SettingsModel.minSizeFitLayouts))
        // (3110 + 10) / 310 = 10, (1270 + 10) / 310 = 4.
        let bsp = try #require(fits[.bsp])
        #expect(bsp.across == 10)
        #expect(bsp.down == 4)
        // Grid's own width: (3110 + 10) / 610 = 5.
        #expect(fits[.grid]?.across == 5)
    }
}
