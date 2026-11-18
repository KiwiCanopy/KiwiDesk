import Foundation
import Testing

/// A Maximize share becomes points in ONE place (#3460,
/// state-and-layout.md ▸ Maximize length):
/// `TilingEngine.maximizedBounds(_:screen:slot:)`, against the fill's
/// own region. A file in either tree that reads a Maximize share and
/// multiplies by a screen length is a second resolution, which a
/// readout or KiwiVision's fill would then disagree with the press
/// on. Scans both trees, comments and literals blanked.
@Suite("Maximize length resolution seam")
struct MaximizeLengthResolutionSeamTests {
    /// What makes a file a reader of a Maximize share.
    private static let subject = try! NSRegularExpression(
        pattern: #"MaximizeLength|heightShare|widthShare|shareOverride"#
            + #"|\.share\(for:|maximizedShape|MaximizeShape"#
    )

    /// A product with a length: `width *`, `* screen.height`,
    /// `length * share`.
    private static let product = try! NSRegularExpression(
        pattern: #"(?i)(width|height|length)\b\s*\*"#
            + #"|\*\s*[\w.]*(width|height|length)\b"#
    )

    /// The one file that may, and why.
    private static let allowed: [String: String] = [
        "TilingEngine+Maximized.swift":
            "maximizedBounds: the one resolution of a share"
    ]

    private static func hits() throws -> Set<String> {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: Set<String> = []
        for tree in ["Sources/KiwiDesk", "Sources/KiwiDeskCore"] {
            let dir = root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                let text = SourceScan.blankingCommentsAndLiterals(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let range = NSRange(text.startIndex..., in: text)
                guard subject.firstMatch(in: text, range: range) != nil,
                    product.firstMatch(in: text, range: range) != nil
                else { continue }
                found.insert(file.lastPathComponent)
            }
        }
        return found
    }

    @Test("only maximizedBounds turns a share into points")
    func oneResolution() throws {
        let found = try Self.hits()
        let strays = found.subtracting(Self.allowed.keys)
        #expect(
            strays.isEmpty,
            Comment(
                rawValue: "a Maximize share resolved outside "
                    + "maximizedBounds: \(strays.sorted())"
            )
        )
    }

    /// The positive control: the scan sees the resolution it allows,
    /// so a needle that stopped matching cannot pass for clean.
    @Test("the scan sees the owner's own product")
    func ownerIsSeen() throws {
        let found = try Self.hits()
        #expect(found.isSuperset(of: Self.allowed.keys))
    }
}
