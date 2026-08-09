import Foundation
import Testing

@testable import KiwiDesk

/// `SourceScan.stripComments` — the primitive every scanning
/// guard reads its input through.
///
/// It earns a suite of its own because its failure mode is
/// invisible from any consumer: a scan that forbids or counts
/// something cannot go red for having been handed less source
/// than it thinks. When the block-comment half first landed it
/// truncated three suites in `Tests/` at an unterminated `/*`
/// inside a string literal, and every guard reading them stayed
/// green over the 230 lines that had gone dark.
@Suite("Source scan comments")
struct SourceScanCommentTests {
    /// The three literal shapes the scanned trees use, each
    /// carrying a `/*` that is not a comment. All three are real
    /// lines from `Tests/KiwiDeskCoreTests`.
    @Test("A block opener inside a string literal is not one")
    func literalsAreNotComments() {
        for line in [
            "entry.hasSuffix(\"/**\")",
            "\"Subsystem map (Sources/KiwiDeskCore/*)\"",
            "#expect(script.contains(#\"\"$LOCALES\"/*.json\"#))",
        ] {
            #expect(
                SourceScan.stripComments(line) == line,
                Comment(rawValue: line)
            )
        }
    }

    /// Spans nest, as they do in Swift. A stripper that stops at
    /// the first `*/` strands the tail, and a stranded tail is
    /// commented-out code standing in for a call site.
    @Test("Nested spans are removed whole")
    func nestedSpansAreRemoved() {
        let source = "before /* outer /* inner */ tail */ after"
        #expect(
            SourceScan.stripComments(source) == "before  after"
        )
    }

    /// Code on the same line as a closed span survives — the
    /// stripper removes comments, not the line they sat on.
    @Test("Code beside a closed span survives")
    func codeBesideASpanSurvives() {
        #expect(
            SourceScan.stripComments("/* noise */ realCall()")
                == " realCall()"
        )
    }

    /// An opener with no closer takes the rest of the file, the
    /// way the compiler reads it — but only outside a literal,
    /// which is the distinction the case above turns on.
    @Test("An unterminated span ends the file")
    func unterminatedSpanEndsTheFile() {
        let stripped = SourceScan.stripComments(
            "kept()\n/* opened\nswallowed()\n"
        )
        #expect(stripped.contains("kept()"))
        #expect(!stripped.contains("swallowed()"))
    }

    /// The canary that would have caught the shipped defect, and
    /// the reason this suite is not three unit tests.
    ///
    /// Balanced stripping keeps every newline it removes text
    /// from, so the stripped form of a real file has exactly as
    /// many lines as the file. A truncation is precisely a loss
    /// of lines — which is what a consumer cannot see and this
    /// can. Scans both trees, because the consumers do: a guard
    /// reading `Tests/` is what went dark.
    @Test("No file in either tree strips short")
    func nothingStripsShort() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var scanned = 0
        for tree in ["Sources", "Tests"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            for file in files {
                let source = try String(
                    contentsOf: file,
                    encoding: .utf8
                )
                let stripped = SourceScan.stripComments(source)
                #expect(
                    stripped.filter { $0 == "\n" }.count
                        == source.filter { $0 == "\n" }.count,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) strips "
                            + "short — a scan of it reads part "
                            + "of the file and cannot tell"
                    )
                )
                scanned += 1
            }
        }
        // A missing directory yields an empty enumerator rather
        // than throwing, so a scan of nothing would pass here
        // exactly as it does in every other consumer (#635).
        #expect(scanned > 300)
    }
}
