import Foundation
import Testing

/// The undrawn-float filter (#2840) has a default reading every
/// float as drawn, so every behaviour suite stays green with the
/// wiring deleted or either consumer reading `floatLayerTargets`
/// again; this pins the one wiring and both consumers.
@Suite("Float raise visibility seam (#2840)")
struct FloatRaiseVisibilitySeamTests {
    @Test("armMachineSeams wires the read once, through the verdict")
    func seamIsWired() throws {
        let body = try SourceScan.functionBody(
            of: "armMachineSeams",
            in: "KiwiCore+BootSeams.swift",
            under: "App"
        )
        #expect(
            body.components(separatedBy: "floatDrawsVisibly = {")
                .count == 2
        )
        #expect(body.contains("KiwiCore.drawsVisibly(bounds: bounds)"))
        #expect(body.contains("SkyLight.windowBounds(wid)"))
    }

    @Test("The raise and its per-focus gate read the drawn targets")
    func consumersTakeTheFilter() throws {
        let pairs = try SourceScan.functionBody(
            of: "floatRaisePairs",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        #expect(pairs.contains("drawnFloatTargets().compactMap"))
        let gate = try SourceScan.functionBody(
            of: "raiseFloatsAbove",
            in: "KiwiCore+ZOrderFloats.swift",
            under: "Commands"
        )
        #expect(gate.contains("!drawnFloatTargets().isEmpty"))
        #expect(!gate.contains("floatLayerTargets()"))
    }
}
