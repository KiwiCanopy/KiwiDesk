import Foundation
import Testing

@testable import KiwiDesk

/// `SourceScan.blankingCommentsAndLiterals` — the primitive the
/// census-render guards, `LocalizedStaticStorageTests` and the
/// layout scans read their input through.
///
/// Its failure mode is the stripper's: a scan handed less source
/// than it thinks cannot go red on its own. The blanker used to
/// toggle on plain `"` and knew neither `"""` nor `#"…"#`, so
/// `ServiceManager.swift`'s plist heredoc — an odd number of
/// quotes, a `\`-continued line — walked it out `inString` and
/// blanked the 264 lines after it, with every consumer green
/// (#1320, found by guard-prover while red-proofing #1311).
@Suite("Source scan blanker")
struct SourceScanBlankerTests {
    /// The #1320 shape: a multiline literal with an odd number of
    /// inner quotes and a `\`-continued line, then a needle.
    private let heredocThenNeedle = """
        let plist = \"\"\"
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \\
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <string>"\\(label)"</string>
        \"\"\"
        static let frozen = L("k", "v")
        """

    @Test("A needle after an odd-quoted heredoc is still visible")
    func heredocDoesNotDarkenTheRest() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            heredocThenNeedle
        )
        #expect(blanked.contains("static let frozen = L("))
        #expect(!blanked.contains("DOCTYPE"))
        #expect(!blanked.contains("PropertyList"))
        #expect(!blanked.contains("\"k\""))
    }

    @Test("A raw literal's interior goes, its quotes stay paired")
    func rawLiteralIsOneLiteral() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            "let a = #\"say \"hi\" /* not */ // nor\"#\nkept()\n"
        )
        #expect(blanked.contains("kept()"))
        #expect(!blanked.contains("hi"))
        #expect(!blanked.contains("not"))
        #expect(!blanked.contains("nor"))
        #expect(blanked.hasPrefix("let a = #\""))
    }

    @Test("An escaped quote does not end a plain literal")
    func escapedQuoteStaysInside() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            "let a = \"x\\\"y\"; kept()\n"
        )
        #expect(blanked.contains("kept()"))
        #expect(!blanked.contains("x"))
        #expect(!blanked.contains("y"))
    }

    @Test("A block span is blanked whole, nested included")
    func blockSpansAreBlanked() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            "a() /* one /* two */ three */ b()\n"
        )
        #expect(blanked.contains("a()"))
        #expect(blanked.contains("b()"))
        #expect(!blanked.contains("one"))
        #expect(!blanked.contains("three"))
    }

    @Test("A comment marker inside a literal is not a comment")
    func markersInsideLiteralsAreNotComments() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            "let u = \"https://kiwidesk.app\"\nHStack(spacing: 6)\n"
        )
        #expect(blanked.contains("HStack(spacing: 6)"))
        #expect(!blanked.contains("kiwidesk"))
    }

    @Test("Every position and every newline survives")
    func positionsAndLinesAreKept() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            heredocThenNeedle
        )
        #expect(blanked.count == heredocThenNeedle.count)
        #expect(
            blanked.filter { $0 == "\n" }.count
                == heredocThenNeedle.filter { $0 == "\n" }.count
        )
    }

    /// The canary, measured from outside as the stripper's is:
    /// every line of both trees that carries neither a quote nor
    /// a comment marker, and does not sit inside a `"""` block,
    /// survives the blanker verbatim. The #1320 defect fails this
    /// on `ServiceManager.swift` at the first quoteless line after
    /// the heredoc, and on every file that acquires the same
    /// shape later.
    ///
    /// The oracle for "inside a block" is line-level parity on
    /// `"""` outside a `//` tail — deliberately coarser than the
    /// walker under test, so it cannot share its mistakes. A
    /// quoteless line inside such a block is SUPPOSED to go, and
    /// every line that opens or closes one carries a quote, so
    /// the toggle is exact.
    @Test("No quoteless, markerless line is ever blanked")
    func nothingGoesDark() throws {
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
                let kept = SourceScan.blankingCommentsAndLiterals(
                    source
                )
                .split(separator: "\n", omittingEmptySubsequences: false)
                let original = source.split(
                    separator: "\n",
                    omittingEmptySubsequences: false
                )
                #expect(kept.count == original.count)
                var insideBlock = false
                for (index, line) in original.enumerated() {
                    let wasInside = insideBlock
                    // A `"""` named in a comment is not one; count
                    // the code before the marker only.
                    let code =
                        line.range(of: "//")
                        .map { line[..<$0.lowerBound] } ?? line[...]
                    if String(code).occurrences(of: "\"\"\"") % 2 == 1 {
                        insideBlock.toggle()
                    }
                    guard index < kept.count, !wasInside else {
                        continue
                    }
                    guard !line.contains("\""),
                        !line.contains("//"),
                        !line.contains("/*"),
                        !line.contains("*/"),
                        !line.trimmingCharacters(in: .whitespaces)
                            .isEmpty
                    else { continue }
                    #expect(
                        kept[index] == line,
                        Comment(
                            rawValue:
                                "\(file.lastPathComponent) line "
                                + "\(index + 1) went dark — a scan "
                                + "of it reads part of the file "
                                + "and cannot tell"
                        )
                    )
                }
                scanned += 1
            }
        }
        // An empty enumerator over a moved directory would pass
        // every check above for having looked at nothing (#635).
        #expect(scanned > 300)
    }
}
