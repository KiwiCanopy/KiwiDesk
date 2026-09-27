import Foundation
import Testing

/// The glyph gap's floor has one home, `clampGlyphGap`, and
/// decode, setter and reader each route through it (#1695) — a
/// hand `max(0, …)` beside it would stay behind when
/// `minGlyphGap` is retuned. Each clause is scoped to the body
/// its subject cannot lose: the decoded key, the setter arm, the
/// reader's declaration.
@Suite("Glyph gap clamp seam")
struct GlyphGapClampSeamTests {
    private static let layouts = "Sources/KiwiDeskCore/Layouts"
    private static let metrics = "\(layouts)/SpaceBarStyle+Metrics.swift"
    private static let coding = "\(layouts)/SpaceBarStyle+Coding.swift"
    private static let setter =
        "Sources/KiwiDeskCore/Commands/SpaceBarCommandSetting.swift"

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(path)
        )
    }

    @Test("the clamp reads the Core floor")
    func clampReadsTheFloor() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "static func clampGlyphGap(",
                in: try source(Self.metrics)
            )
        )
        #expect(body.contains("minGlyphGap"))
    }

    /// The one decode of the key sits inside the clamp's
    /// arguments.
    @Test("decode hands the key to the clamp")
    func decodeRoutes() throws {
        let text = try source(Self.coding)
        let key = "forKey: .glyphGap"
        #expect(text.components(separatedBy: key).count == 2)
        let args = try #require(
            SourceScan.callArguments(of: "clampGlyphGap(", in: text)
        )
        #expect(args.contains(key))
    }

    /// The arm runs to the next `case` label.
    @Test("the setter arm routes through the clamp")
    func setterRoutes() throws {
        let text = try source(Self.setter)
        let arm = try #require(
            text.range(of: "case .glyphGap(let value):")
        )
        let rest = text[arm.upperBound...]
        let end =
            rest.range(of: "\n        case ")?.lowerBound
            ?? rest.endIndex
        #expect(rest[..<end].contains("clampGlyphGap("))
    }

    @Test("the reader routes through the clamp")
    func readerRoutes() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "var resolvedGlyphGap:",
                in: try source(Self.metrics)
            )
        )
        #expect(body.contains("clampGlyphGap("))
    }
}
