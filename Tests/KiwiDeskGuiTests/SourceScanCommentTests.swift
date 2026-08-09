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

    /// Files that legitimately carry a `/* … */` span, and whose
    /// interior lines the stripper is therefore SUPPOSED to
    /// remove. Empty, and the emptiness is the point: the repo
    /// writes `//`. A file joining this list is opting out of the
    /// check below, so it needs a reason.
    private let usesBlockComments: Set<String> = []

    /// The canary, and the reason this suite is not three unit
    /// tests: a scan handed less source than it thinks cannot go
    /// red on its own, so something has to measure the darkness
    /// from outside.
    ///
    /// It measures it **directly** — every line carrying no
    /// comment marker survives verbatim — after the first cut
    /// keyed on line COUNT, which could not fail: the walk
    /// preserves newlines inside a span by construction, so no
    /// input can strip short. Deleting the string-literal skip,
    /// which is the defect this suite exists for, left 72% of
    /// `CiPathFilterTests.swift` dark with that canary green on
    /// all 1165 files (code review, 2026-08-09).
    ///
    /// Scans both trees, because the consumers do: the guards
    /// reading `Tests/` are the ones that went dark.
    @Test("No line without a comment marker is ever dropped")
    func nothingGoesDark() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var scanned = 0
        for tree in ["Sources", "Tests"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            for file in files
            where !usesBlockComments.contains(
                file.lastPathComponent
            ) {
                let source = try String(
                    contentsOf: file,
                    encoding: .utf8
                )
                // Membership over the stripped file's own
                // lines: a substring search per line turned this
                // into a 20-second suite over 1165 files.
                let kept = Set(
                    SourceScan.stripComments(source)
                        .split(separator: "\n")
                )
                for line in source.split(separator: "\n")
                where !line.contains("//")
                    && !line.contains("/*")
                    && !line.contains("*/")
                    && !line.trimmingCharacters(
                        in: .whitespaces
                    ).isEmpty
                {
                    let lost = line.trimmingCharacters(
                        in: .whitespaces
                    )
                    #expect(
                        kept.contains(line),
                        Comment(
                            rawValue:
                                "\(file.lastPathComponent) lost "
                                + "`\(lost)` — a scan of it reads "
                                + "part of the file and cannot tell"
                        )
                    )
                }
                scanned += 1
            }
        }
        // A missing directory yields an empty enumerator rather
        // than throwing, so a scan of nothing would pass here
        // exactly as it does in every other consumer (#635).
        #expect(scanned > 300)
    }
}
