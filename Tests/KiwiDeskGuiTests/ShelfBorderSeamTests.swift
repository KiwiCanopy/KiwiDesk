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

    /// The active indicator's outline, the one other layer border
    /// `Bar/` strokes: file and write count per channel, so a new
    /// write — even one spelled like the accent's — reds until it
    /// is ruled. The width is counted on its own: CALayer's default
    /// border colour is opaque black, so a width alone draws a rim.
    /// The App Bar item's width count includes its own layer's
    /// reset to 0, which draws nothing; so does the front chip's
    /// indicator (#1856), the Space item's accent laid on the chip.
    private static let allowedColor: [String: Int] = [
        "AppBarItemView+Paint.swift": 1,
        "SpaceBarItemView+Style.swift": 1,
        "SpaceBarOverlay+FrontAccent.swift": 1,
    ]
    private static let allowedWidth: [String: Int] = [
        "AppBarItemView+Paint.swift": 3,
        "SpaceBarItemView+Style.swift": 2,
        "SpaceBarOverlay+FrontAccent.swift": 2,
    ]

    /// Per `Bar/` file, how many assignments to `property` it
    /// makes, whatever the spacing, never a `==` comparison.
    private static func writes(
        of property: String
    ) throws -> [String: Int] {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(property)\\s*=(?!=)"
        )
        let bar = coreRoot.appendingPathComponent("Bar")
        var writes: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: bar) {
            let source = try SourceScan.strippedSource(at: file)
            let count = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            if count > 0 { writes[file.lastPathComponent] = count }
        }
        return writes
    }

    /// A layer border in `Bar/` is the active indicator's or the
    /// painter's; any other one is a second rim.
    @Test(
        "Bar/ strokes a layer border only in the painter or accent",
        arguments: ["borderColor", "borderWidth"]
    )
    func noSecondRim(property: String) throws {
        var writes = try Self.writes(of: property)
        #expect(
            writes.removeValue(forKey: Self.home) != nil,
            "the painter no longer writes \(property)"
        )
        let allowed =
            property == "borderColor"
            ? Self.allowedColor : Self.allowedWidth
        #expect(writes == allowed, "\(property): \(writes)")
    }
}
