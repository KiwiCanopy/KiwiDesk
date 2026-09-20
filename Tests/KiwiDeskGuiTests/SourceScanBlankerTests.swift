import Foundation
import Testing

@testable import KiwiDesk

/// `SourceScan.blankingCommentsAndLiterals` — the primitive the
/// census-render guards, `LocalizedStaticStorageTests` and the
/// layout scans read their input through.
///
/// Its failure mode is the stripper's: a scan handed less source
/// than it thinks cannot go red on its own. The blanker used to
/// toggle on every plain `"`, so a `"""` block flipped it three
/// times at each end and every inner quote once, and a `//`
/// inside the block was read as a comment that ate the quote
/// balancing it — `ServiceManager.swift`'s plist heredoc did
/// both, and 264 of its 283 lines were dark to every consumer
/// (#1320, found by guard-prover while red-proofing #1311). The
/// two fixtures below take the two mechanisms one at a time.
@Suite("Source scan blanker")
struct SourceScanBlankerTests {
    /// The `ServiceManager` shape: a `//` inside a `"""` block, on
    /// a `\`-continued line, then a needle. The old toggle read
    /// that `//` as a comment and lost the block's balance there.
    private let heredocThenNeedle = """
        let plist = \"\"\"
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \\
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <string>"\\(label)"</string>
        \"\"\"
        static let frozen = L("k", "v")
        """

    /// The parity shape: a `"""` block holding ONE inner quote and
    /// no `//`. The old toggle came out of the block `inString`
    /// on the count alone.
    private let oddQuotedBlock = """
        let sql = \"\"\"
        SELECT "name
        \"\"\"
        static let frozen = L("k", "v")
        """

    @Test("A needle after a heredoc with a // in it is still visible")
    func heredocDoesNotDarkenTheRest() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            heredocThenNeedle
        )
        #expect(blanked.contains("static let frozen = L("))
        #expect(!blanked.contains("DOCTYPE"))
        #expect(!blanked.contains("PropertyList"))
        #expect(!blanked.contains("\"k\""))
        // The delimiters survive WHOLE: a walk keeping one quote
        // of each `"""` keeps every position and still lies.
        #expect(
            blanked.occurrences(of: "\"\"\"")
                == heredocThenNeedle.occurrences(of: "\"\"\"")
        )
    }

    @Test("A needle after an odd-quoted block is still visible")
    func oddQuotedBlockDoesNotDarkenTheRest() {
        let blanked = SourceScan.blankingCommentsAndLiterals(
            oddQuotedBlock
        )
        #expect(blanked.contains("static let frozen = L("))
        #expect(!blanked.contains("SELECT"))
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
        #expect(blanked.contains("\"#\nkept()"))
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
        // Blanking the `//` as a COMMENT would satisfy both lines
        // above; only a literal walk keeps the closing quote.
        #expect(blanked.contains("let u = \""))
        #expect(blanked.contains("\"\nHStack"))
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
    /// `"""` — after a `//` tail and any `#"…"#` on the line are
    /// dropped, since a raw literal ending in `""` spells one
    /// with its own closer (`#"KEEP_SIG="""#`) — deliberately
    /// coarser than the walker under test, so it cannot share its
    /// mistakes. A quoteless line inside such a block is SUPPOSED
    /// to go, and every line that opens or closes one carries a
    /// quote. The oracle must be CLOSED at each file's end and
    /// must have judged something, or a desync of its own would
    /// skip the rest of a file with this suite green. Residue: two
    /// stray `"""` in one file cancel and leave the lines between
    /// them unjudged with the file closed — empty today, and the
    /// floor below would not move on it.
    @Test("No quoteless, markerless line is ever blanked")
    func nothingGoesDark() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var scanned = 0
        var judged = 0
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
                #expect(
                    kept.count == original.count,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent) came back "
                            + "\(kept.count) lines for "
                            + "\(original.count) — the per-line "
                            + "check below is silent past the end"
                    )
                )
                var insideBlock = false
                for (index, line) in original.enumerated() {
                    let wasInside = insideBlock
                    if Self.tripleQuotes(in: String(line)) % 2 == 1 {
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
                    judged += 1
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
                #expect(
                    !insideBlock,
                    Comment(
                        rawValue:
                            "\(file.lastPathComponent): the oracle "
                            + "ended inside a block, so it judged "
                            + "nothing after the desync"
                    )
                )
                scanned += 1
            }
        }
        // An empty enumerator over a moved directory would pass
        // every check above for having looked at nothing (#635),
        // and so would an oracle that skipped every line.
        #expect(scanned > 300)
        #expect(judged > 10_000)
    }

    /// `"""` occurrences that open or close a block on this line:
    /// a `//` tail and every `#"…"#` raw literal are dropped first.
    private static func tripleQuotes(in line: String) -> Int {
        var code =
            line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? line
        while let open = code.range(of: "#\""),
            let close = code.range(
                of: "\"#",
                range: open.upperBound..<code.endIndex
            )
        {
            code.removeSubrange(open.lowerBound..<close.upperBound)
        }
        return code.occurrences(of: "\"\"\"")
    }
}
