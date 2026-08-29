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
        // Bounded to the function's BRACE-BALANCED body, not the
        // rest of the file (code review, 2026-08-29): a slice
        // running to EOF is satisfied by any later mention of
        // the name — a doc comment on a function appended below
        // — while the call itself is gone. tests.md: where a
        // needle is read is as load-bearing as what it reads.
        let body = try #require(
            Self.balancedBody(of: source, from: sweep.upperBound)
        )
        // The memo consultation rides the same needle: its
        // EFFECT is guarded at `KiwiCore` altitude
        // (`FloatRegionFitTests`), but only a scan can see that
        // the sweep still asks — deleting the call left the
        // whole suite green (guard-prover, 2026-08-29).
        #expect(
            body.contains("shouldIssueFloatFit("),
            """
            the retile-time float sweep must consult the refusal \
            memo — without it an app whose minimum exceeds the \
            region is re-asked to shrink on every retile, forever
            """
        )
        #expect(
            body.contains("floatFitLedger.forget("),
            """
            the sweep must drop a window's memo when it needs no \
            fit, or a window that later needs one is never asked
            """
        )
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
