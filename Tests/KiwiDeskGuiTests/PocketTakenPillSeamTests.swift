import Testing

/// The second-window Pocket refusal (#2675) hands the pill the
/// pocket's taken glyph, not the shared `nosign` of the float
/// refusals; a unit test of the glyph cannot see the call site.
@Suite("Pocket taken pill seam")
struct PocketTakenPillSeamTests {
    @Test("the refusal names the taken glyph")
    func refusalNamesTheTakenGlyph() throws {
        let body = try SourceScan.functionBody(
            of: "refuseSecondPocketWindow",
            in: "KiwiCore+PocketWindow.swift",
            under: "Commands"
        )
        #expect(body.contains("flashRefusalPill("))
        #expect(body.contains("symbol: PocketMark.takenName"))
    }
}
