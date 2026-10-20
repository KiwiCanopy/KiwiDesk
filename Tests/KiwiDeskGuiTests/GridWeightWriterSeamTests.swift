import Foundation
import Testing

/// The grid weight write (#763) is a raw session-layer writer: its
/// clamp is `GridTracks.moveEdge`'s, upstream in the one
/// `resizeGridMember` both the keyboard verb and the mouse drop
/// take. A second caller beside a resize site would write past
/// the floors with nothing red — the #933 hazard the capped
/// writers exist for — so the call has one home.
@Suite("Grid weight writer seam (#763)")
struct GridWeightWriterSeamTests {
    @Test("writeGridWeights is called from resizeGridMember alone")
    func oneCaller() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var calls: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let hits =
                source.components(
                    separatedBy: "writeGridWeights("
                ).count - 1
            let defs =
                source.components(
                    separatedBy: "func writeGridWeights("
                ).count - 1
            guard hits - defs > 0 else { continue }
            calls[String(file.path.dropFirst(prefix.count))] =
                hits - defs
        }
        #expect(calls == ["Commands/KiwiCore+ResizeGrid.swift": 1])
    }
}
