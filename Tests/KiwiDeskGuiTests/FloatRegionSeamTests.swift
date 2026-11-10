import Foundation
import Testing

/// The retile-time float net pushes and never fits (#3163).
///
/// `FloatNeverResizedTests` and `FloatingModeBarClampTests` hold the
/// behaviour; only a scan can see which verdict the sweep routes
/// through and that the retired fit stays retired.
@Suite("Float region seam (#3163)")
struct FloatRegionSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("The retile net takes the push verdict on the would-be frame")
    func retileNetUsesThePushVerdict() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/App/KiwiCore+FloatClamp.swift"
        )
        let source = try SourceScan.strippedSource(at: file)
        let sweep = try #require(
            source.range(of: "func clampFloatsClearOfBars()")
        )
        // Bounded to the function's brace-balanced body: a slice
        // running to EOF is satisfied by a later mention.
        let body = try #require(
            Self.balancedBody(of: source, from: sweep.upperBound)
        )
        // One verdict the sweep and the resize arm share (#1358).
        #expect(
            body.contains("floatBarPush("),
            "the sweep must take its verdict from floatBarPush"
        )
        // The stale state frame's push lands after a delivery and
        // undoes it (#3157).
        #expect(
            body.contains("wouldBeFrame(of: window)"),
            "the sweep must judge the frame the window would show"
        )
    }

    /// A scan for a retired API keeps it retired (tests.md): the
    /// #1091 fit, its refusal memo and the #1427 drop fit resized a
    /// float the user had placed.
    @Test("No float fit is left in Core")
    func noFloatFitInCore() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        let retired = [
            "FloatFitLedger",
            "floatFrameFittedClearOfBars",
            "floatFrameFittedOnDrop",
            "shouldIssueFloatFit",
        ]
        var hits: [String: [String]] = [:]
        let files = try SourceScan.swiftSources(under: core)
        #expect(!files.isEmpty)
        for file in files {
            let source = try SourceScan.strippedSource(at: file)
            let found = retired.filter { source.contains($0) }
            if !found.isEmpty { hits[file.lastPathComponent] = found }
        }
        #expect(hits.isEmpty)
    }

    /// The brace-balanced body that opens at or after `start`.
    /// A per-file private helper, per tests.md's convention —
    /// nothing else needs it yet.
    private static func balancedBody(
        of source: String,
        from start: String.Index
    ) -> Substring? {
        guard
            let open = source[start...].firstIndex(of: "{")
        else { return nil }
        var depth = 0
        var index = open
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 {
                    return source[open...index]
                }
            }
            index = source.index(after: index)
        }
        return nil
    }
}
