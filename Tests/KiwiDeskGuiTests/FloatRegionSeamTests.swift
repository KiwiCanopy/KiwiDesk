import Foundation
import Testing

/// The retile-time net routes through the FITTING entry (#1091).
///
/// `FloatRegionFitTests` proves the fit itself works; nothing it
/// can assert proves the retile still calls it. Collapsing
/// `floatFrameFittedClearOfBars` back to the clamp beside it was
/// green across all 4239 tests before that suite existed, and
/// re-pointing the caller is the same defect one level up — a
/// two-character edit that silently restores "a float grown
/// before this rule stays unusable under a bar".
@Suite("Float region seam (#1091)")
struct FloatRegionSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("The retile net calls the fitting entry, once")
    func retileNetUsesTheFittingEntry() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/App/KiwiCore+FloatClamp.swift"
        )
        let source = try String(contentsOf: file, encoding: .utf8)
        // A shape pin, not a value one: it holds that the sweep
        // routes through the fitting entry, never what the fit
        // computes. `clampFloatsClearOfBars` is the sweep; the
        // needle is its call, so re-pointing it at the
        // clamp-only sibling reds.
        let sweep = try #require(
            source.range(of: "func clampFloatsClearOfBars()")
        )
        let body = source[sweep.lowerBound...]
        #expect(
            body.contains("floatFrameFittedClearOfBars("),
            """
            the retile-time float sweep must call \
            floatFrameFittedClearOfBars — the clamp-only sibling \
            moves a window without ever bounding its size, which \
            is the #1091 defect
            """
        )
    }
}
