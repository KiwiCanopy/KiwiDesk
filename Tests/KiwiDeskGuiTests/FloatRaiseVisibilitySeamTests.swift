import Foundation
import Testing

/// The float raise's drain needs live `AXUIElement`s, so no unit
/// test reaches `floatRaisePairs` (`FloatRaiseLandingWiringTests`
/// says the same of the landing); this pins that it, and the
/// verdict both raise paths ask, still read the #2840 filter.
/// Reading `floatLayerTargets` there again leaves every behaviour
/// suite green while the invisible helper drains on every step.
@Suite("Float raise visibility seam (#2840)")
struct FloatRaiseVisibilitySeamTests {
    @Test("The raise's targets are the drawn targets")
    func raiseTakesTheFilter() throws {
        let pairs = try SourceScan.functionBody(
            of: "floatRaisePairs",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        #expect(pairs.contains("drawnFloatTargets().compactMap"))
        #expect(!pairs.contains("floatLayerTargets()"))
    }

    @Test("The verdict reads the watch's bounds seam")
    func verdictReadsTheSeam() throws {
        let verdict = try SourceScan.functionBody(
            of: "floatIsDrawn",
            in: "KiwiCore+ZOrderFloatLayer.swift",
            under: "Commands"
        )
        #expect(verdict.contains("FloatDetection.drawsVisibly("))
        #expect(verdict.contains("windowServer.readWindowBounds(id)"))
    }
}
