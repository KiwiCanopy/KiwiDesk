import Foundation
import Testing

@testable import KiwiDesk

/// The Bars preview decides plate-or-boxes from Core's ONE answer,
/// `KiwiShelf.drawsPlate` (#1517 architect re-review): `hasBox`
/// answers whether an item paints a SOLID box and is false for
/// Boxed with Liquid Glass, so a preview keyed on it drew a plate
/// the live shelf never draws.
@Suite("Bars preview plate seam")
struct BarsPreviewPlateSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("Both bar specs box exactly where no plate is drawn")
    func specsRouteThroughDrawsPlate() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/HomeCardPlate+Bars.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(!source.isEmpty)
        let routed =
            source.components(
                separatedBy: ",boxed:!style.shelf.drawsPlate,"
            ).count - 1
        let assigned = source.components(separatedBy: ",boxed:").count - 1
        #expect(routed == 2)
        #expect(assigned == routed)
        #expect(!source.contains("hasBox"))
    }
}
