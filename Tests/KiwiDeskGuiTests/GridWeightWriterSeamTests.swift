import Foundation
import Testing

/// The raw grid weight write has one caller, `resizeGridMember`,
/// whose `GridTracks.moveEdge` is its clamp (#763, #933).
@Suite("Grid weight writer seam (#763)")
struct GridWeightWriterSeamTests {
    private static let call = "writeGridWeights("

    @Test("writeGridWeights is called from resizeGridMember alone")
    func oneCaller() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var total = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            total +=
                source.components(separatedBy: Self.call).count
                - source.components(
                    separatedBy: "func " + Self.call
                ).count
        }
        let body = try SourceScan.functionBody(
            of: "resizeGridMember",
            in: "KiwiCore+ResizeGrid.swift",
            under: "Commands"
        )
        let inBody = body.components(separatedBy: Self.call).count - 1
        #expect(inBody == 1)
        #expect(total == inBody)
    }
}
