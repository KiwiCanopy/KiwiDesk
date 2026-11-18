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
        let fits = MinSizeFitLine.sentence(
            for: MinSizeFit(screen: "Studio", across: 7, down: 2)
        )
        #expect(fits == "On Studio, this fits 7 across and 2 down.")
        // Either axis at nothing takes the other sentence.
        for fit in [
            MinSizeFit(screen: "Studio", across: 0, down: 2),
            MinSizeFit(screen: "Studio", across: 3, down: 0),
        ] {
            #expect(
                MinSizeFitLine.sentence(for: fit)
                    == "Larger than Studio, so a window there can't "
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
        #expect(
            source.occurrences(
                of: "if !model.minSizesDiffer {\n"
                    + "                    MinSizeFitLine(fit: "
                    + "fit(model.minSizeMostUsed))"
            ) == 1
        )
        #expect(
            source.occurrences(
                of: "if model.minSizesDiffer, "
                    + "Self.fitLayouts.contains(layout) {\n"
                    + "                MinSizeFitLine(fit: fit(layout))"
            ) == 1
        )
        #expect(
            source.occurrences(
                of: "didChangeScreenParametersNotification"
            ) == 1
        )
        #expect(
            MinWindowSizeRows.fitLayouts == [.stack, .grid, .track, .bsp]
        )
    }
}
