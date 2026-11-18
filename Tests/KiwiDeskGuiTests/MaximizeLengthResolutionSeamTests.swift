import Foundation
import Testing

/// A Maximize share becomes points in ONE place (#3460,
/// state-and-layout.md ▸ A Maximize length resolves):
/// `TilingEngine.maximizedBounds(_:screen:slot:)`, against the fill's
/// own region, which Settings reaches only through
/// `KiwiCore.maximizeRegion(on:)`. A file in either tree that reads a
/// Maximize share and multiplies or divides by a screen length is a
/// second resolution, which a readout would then disagree with the
/// press on. Scans both trees, comments and literals blanked.
///
/// What it cannot see: a length named another way (`whole`,
/// `extent`, `rect.maxX`); a file that reads a share without naming
/// one of `subject`'s tokens; and which region a resolution is
/// handed. The allowed file is exempt whole, not only its
/// resolution.
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
        pattern: #"(?i)(width|height|length)\b\s*[*/]"#
            + #"|[*/]\s*[\w.]*(width|height|length)\b"#
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

    /// Settings takes the region door, never the engine's function.
    @Test("the GUI never calls maximizedBounds")
    func guiTakesTheDoor() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var callers: [String] = []
        for file in try SourceScan.swiftSources(under: dir) {
            let text = SourceScan.blankingCommentsAndLiterals(
                try String(contentsOf: file, encoding: .utf8)
            )
            if text.contains("maximizedBounds(") {
                callers.append(file.lastPathComponent)
            }
        }
        #expect(callers.isEmpty, Comment(rawValue: "\(callers)"))
    }

    /// The positive control: the scan sees the resolution it allows,
    /// so a needle that stopped matching cannot pass for clean.
    @Test("the scan sees the owner's own product")
    func ownerIsSeen() throws {
        let found = try Self.hits()
        #expect(found.isSuperset(of: Self.allowed.keys))
    }
}
