import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The bar thickness sliders' band is ONE value, and its floor
/// is the Core floor by derivation (#1359).
///
/// A restated floor of 30 shipped for two months over a Core
/// floor of 20, and the gap was a legal stored value the GUI
/// could not reach: touch the slider once and 28 was gone for
/// good. Nothing red, because the two numbers lived in files
/// nothing compared. The first clause compares them; the second
/// holds that every thickness slider takes the band from its one
/// home, so a third card cannot restate a number the first
/// clause would never see.
@Suite("Bar thickness slider band")
struct BarThicknessRangeTests {
    @Test("the band's floor IS the Core floor, and holds the default")
    func floorIsTheCoreFloor() {
        let band = SettingsMetrics.barThicknessRange
        #expect(band.lowerBound == Double(AppBarStyle.minThickness))
        #expect(band.contains(Double(AppBarStyle().thickness)))
        #expect(band.contains(Double(SpaceBarStyle().thickness)))
    }

    @Test("every thickness slider takes the one band")
    func everyThicknessSliderTakesTheOneBand() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var sliders = 0
        for file in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: file)
            var rest = text
            while let made = rest.range(of: "PtSlider(") {
                let args = SourceScan.callArguments(
                    of: "PtSlider(",
                    in: rest
                )
                rest = String(rest[made.upperBound...])
                // A thickness row is named by its label key; the
                // key is the census's and survives a relabel.
                guard let args, args.contains(".thickness\"")
                else { continue }
                sliders += 1
                #expect(
                    args.contains(
                        "range: SettingsMetrics.barThicknessRange"
                    ),
                    "\(file.lastPathComponent) restates the band"
                )
            }
        }
        #expect(sliders > 0, "the scan found no thickness slider")
    }
}
