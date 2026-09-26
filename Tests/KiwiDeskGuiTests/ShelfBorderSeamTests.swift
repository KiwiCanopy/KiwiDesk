import Foundation
import Testing

@testable import KiwiDesk

/// The shelf's border is painted in ONE place (#1679, bars.md):
/// `ShelfBorder.paint` is the only Core reader of the drawn width,
/// and inside `Bar/` the only layer-border writes beside it are the
/// active indicator's. A rim drawn beside the painter would skip
/// the switch, the clamp or the surface rule.
@Suite("Shelf border seam")
struct ShelfBorderSeamTests {
    private static let home = "ShelfBorder.swift"

    private static var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Where the width is declared, and the one painter.
    private static let readers: Set<String> = [
        "KiwiShelf.swift", home,
    ]

    @Test("Only the painter reads the drawn border width")
    func onePainterReadsTheWidth() throws {
        var hits: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.coreRoot) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("drawnBorderWidth") {
                hits.insert(file.lastPathComponent)
            }
        }
        #expect(scanned >= 200, "scanned \(scanned) files")
        // Equality, so the painter must still read it too.
        #expect(hits == Self.readers, "\(hits)")
    }

    /// A layer border in `Bar/` is the active indicator's or the
    /// painter's; any other one is a second rim.
    @Test("Bar/ strokes a layer border only in the painter or accent")
    func noSecondRim() throws {
        let bar = Self.coreRoot.appendingPathComponent("Bar")
        var strays: [String] = []
        var painterWrites = false
        for file in try SourceScan.swiftSources(under: bar) {
            let name = file.lastPathComponent
            let source = try SourceScan.strippedSource(at: file)
            for line in source.split(separator: "\n")
            where line.contains("borderColor =") {
                if name == Self.home {
                    painterWrites = true
                } else if !line.contains("accent.layer?.borderColor") {
                    strays.append("\(name): \(line)")
                }
            }
        }
        #expect(painterWrites, "the painter no longer strokes")
        #expect(strays.isEmpty, "\(strays)")
    }
}
