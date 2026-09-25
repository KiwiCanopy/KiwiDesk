import Foundation
import Testing

/// Both bars refresh through the one `KiwiCore.updateBars()`
/// (#1517): it builds each display's shelf plan once and syncs
/// both managers from it, so a path that synced one manager on
/// its own would leave the other bar in a segment the plan no
/// longer gives it. The managers' `sync(` therefore has one home.
@Suite("Bar refresh seam (#1517)")
struct BarsRefreshSeamTests {
    @Test("the bar managers are synced only by the shelf refresh")
    func syncHasOneHome() throws {
        let core = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var homes: [String: Int] = [:]
        let files = try FileManager.default.subpathsOfDirectory(
            atPath: core.path
        )
        .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        for file in files {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: core.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            let count =
                source.components(separatedBy: "appBars.sync(").count
                + source.components(separatedBy: "spaceBars.sync(")
                .count - 2
            if count > 0 { homes[file] = count }
        }
        #expect(Set(homes.keys) == ["App/KiwiCore+Shelf.swift"])
    }
}
